---
name: edge-bpu-runtime-iova
description: >-
  Edge NPU/BPU multi-model runtime methodology for IOVA / IOMMU mapping failures,
  load-order contracts, co-preload of peer AR segments, lifetime caching of
  runtimes, core binding, mutex sessions, and poisoned accelerator state. Use
  when loading multiple HBMs, seeing "iova addr not equal for different core",
  false "model corrupted" after an earlier successful load/infer, Talker-then-
  late-MTP (or similar sibling) failures, ASR/TTS switching, multi-mode board
  smoke (A/B/C), or designing pipelines that share one SoC.
---

# 边缘加速器多模型运行时（IOVA / 加载序）

适用于在同一 SoC 上先后或同时加载多个加速器模型包（HBM / 分段图 / AR leap 等）时的运行时契约。目标：**从根上避免映射表被打乱**，而不是每次毒化后靠重启碰运气。

## 1. 问题定义

多模型上板常见失败：

- 单模可加载，第二模加载报 IOVA / IOMMU 不一致
- 日志写「模型损坏 / lib 需升级」，实为映射冲突的次生文案
- **兄弟段晚加载**：已加载并推理过 A（如 Talker），再加载本应同会话的 B（如 MTP）失败——即使从未 `del`
- **同会话 `del` / 每次 new Runtime**：先成功，再构造加载失败，并毒化整机
- 进程退出后新进程仍无法加载，直至整机重启
- 评测「先单模再组合」或「A→C→B 中途才去 load 第二段」把板端毒化
- 两路业务抢同一 BPU 核导致串场（如 Codec↔Decoder）

本 skill 管**加载、绑核、同预载、实例生命周期、进程边界、毒化恢复**；量化精度见 `horizon-bpu-ptq`，实验置信度见 `field-validation-method`。

## 2. 不变量 / 第一性原理

1. **映射表是全局稀缺状态**：主机物理页 ↔ 各核 IOVA 一经建立，错误的二次加载会弄乱表；进程结束≠表已干净。
2. **加载序是契约，不是风格**：能共存的组合必须写成「先谁后谁 / 是否允许推理穿插」；未验证的序默认禁止。
3. **同进程要用的集合，推理前一次定好**：含全部兄弟 AR 段；禁止「先跑 A 再晚加载 B」。
4. **兄弟段同预载**：凡同会话会用到的 peer 模型（Talker+MTP、Enc+Dec、Feat+Init…），在**任一 peer 首次推理前**全部 load 完；「C 只用 Talker」也不能省掉 MTP 预载——若随后还要跑 B。
5. **已加载实例是热资源**：默认缓存到进程结束；`del rt` / 每次 `new Runtime(hbm)` ≠ 安全卸载。
6. **核是预算**：冲突核上的业务只能**互斥会话**；切换通常须用户冷启动。
7. **毒化后可靠恢复往往是冷启动**：Agent **不得擅自 reboot**；停测并请用户重启。
8. **加载门禁 ≠ 任务门禁**：IOVA 通过只说明能跑；qcos/听感/CER 另报（`horizon-bpu-ptq`）。

## 3. 架构 / 选型决策树

```text
要在板上跑 ≥2 个加速器模型？
  ├─ 必须同进程（流水 / 多模式一次跑完）？
  │     ├─ 已有验证契约？
  │     │     → 会话开始：按序 preload 全集（含后续模式才用的兄弟段）并缓存
  │     │     → 模式切换只复用；禁止 del/reload；禁止推理后再 load 兄弟段
  │     └─ 没有？ → 最小对照（合规 vs 违规）后再写 configs，禁止直接上 Web
  ├─ 可分进程？
  │     ├─ A 退出后 B 能 load → 分进程编排
  │     └─ 不能 → 互斥会话；中间用户冷启动
  ├─ 多模式（A/B/C/synth）？
  │     ├─ 同 boot → 开场就把 B/synth 需要的 AR 栈预载齐（不要等跑到 B 才 load MTP）
  │     └─ 无法常驻 → 每模式独立冷启动
  └─ 与常驻 daemon 抢核？
        → 核预算表；勿默认 kill 常驻服务
```

| 模式 | 何时用 | 约束 |
|------|--------|------|
| 同进程全 preload + 缓存 | ASR enc+dec；TTS Codec→(Talker+MTP)；视觉多段 | 推理前齐套；实例不销毁 |
| 兄弟段同预载 | 任一模式可能用到 peer | 即使当前模式不用 peer，只要同会话后续要用就必须先载 |
| 有序释放再 load | 仅当实验证明可再 load | 多数栈上 **`del` 不够**；默认禁止 |
| 分进程互斥 | TTS ↔ ASR 等共享核 | 一次 boot 一种管线 |
| 重段优先 | Codec / 大包更敏感 | 先 Codec（或板上对照确认的重段） |

## 4. 标准操作流程 SOP

### 4.1 设计阶段

1. 列出会话内全部加速器产物与角色。
2. 画 **core 预算表**（含 daemon）。
3. 写死 **load order**、**同预载集合**、**lifetime**。
4. API：`_talker()` / `_mtp()` / `_encoder()` 等必须**单例缓存**；提供 `_ensure_ar_stack()` 一类「齐套预载」入口。
5. 配置落盘（`bpu_cores.json`、`bpu_session_contract.json`）。

### 4.2 冒烟（短、可回滚）

1. 冷启动 → 只跑契约路径（齐套 preload + 多模式连续推理）。
2. 对照禁止路径（预期失败并文档化）：
   - 先单模推理再晚加载兄弟段
   - load→infer→`del`→再 load
3. 分进程毒化测试 → 标互斥或可共存。
4. 通过后才允许 Web / 长评测。

### 4.3 评测

1. 会毒化 stage：分进程，或同进程**零卸载 + 开场齐套预载**。
2. 禁止：encoder-only→dual-load；Talker 推理后再 load MTP；模式间 `del` AR。
3. 一现 IOVA / 假 corrupted → **停测**，请用户冷启动。

### 4.4 Agent 行为

- 当 IOVA / 假 corrupted 处理，勿当文件损坏反复推送。
- 上一模式成功、下一模式 load 失败 → 先查 **晚加载兄弟段 / reload**。
- **禁止**擅自 reboot/shutdown。
- 汇报：主机角色、核表、预载集合、是否毒化、是否待用户重启；加载门禁与精度门禁分开写。

## 5. 度量与门禁

| 类型 | 虚荣 | 验收 |
|------|------|------|
| 加载 | 单模 Runtime OK | 契约下齐套 preload + 连续多模式推理无 IOVA |
| 同预载 | 「C 不用 MTP 所以没载」 | 同 boot 再跑 B/synth 仍成功（MTP 开场已载） |
| 生命周期 | 「del 了应该释放了」 | del→reload 失败则禁止该写法 |
| 互斥 | 同 boot 硬塞 ASR+TTS | 文档化互斥；切换冷启动 |
| 恢复 | kill 进程 | 新进程可 load **或** 明确须冷启动 |
| 任务 | 能出 wav/文本 | 另报 qcos/CER/听感（与 IOVA 分列） |

## 6. 故障分类学

| 症状 | 可能原因 | 否证 / 处置 |
|------|----------|-------------|
| `iova addr not equal for different core` | 二次加载 / 晚加载兄弟段 | 冷启动 + 齐套预载对照 |
| `Hbm corrupted` 但 md5 不变 | 次生误报 | 当 IOVA；冷启动后同文件能 load 即证实 |
| C（仅 Talker）成功，B load MTP 失败 | **推理后再载兄弟段** | 开场 `_ensure_ar_stack()` 同预载 Talker+MTP |
| A/C 成功，同进程再 new Talker/MTP 失败 | del 或工厂未缓存 | 单例缓存；禁止 reload |
| 新进程也失败 | 跨进程毒化 | 互斥；请用户冷启动；停测 |
| ASR↔TTS 切换失败 | 共享核 | 会话互斥 |
| IOVA 过但 qcos≈0 / 噪声 | 精度问题 | 走 `horizon-bpu-ptq`，勿与加载契约混为一谈 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| C 省掉 MTP 预载，跑到 B 再 load | 晚加载兄弟段 IOVA | 开场齐套预载 |
| 每次 `_talker()` new Runtime | 第二次=二次加载 | 进程内单例 |
| 模式结束 `del` + `gc` | 映射未安全释放 | 常驻到进程结束 |
| 同 boot 连跑 ASR 与 TTS | 共享核毒化 | 互斥 + 用户冷启动 |
| 把 corrupted 当坏文件 scp | 掩盖真因 | md5 + 冷启动对照 |
| Agent 自行 reboot | 藏证据、扰用户 | 请用户重启 |
| IOVA 一过就宣称 freerun 可用 | 加载≠任务达标 | 分列精度门禁 |
| Web 默认 sticky/PCA 等未验证捷径 | 噪声回归 | 捷径 opt-in；主路径过契约 |

## 8. 交付 / 复盘清单

- [ ] 模型列表、core 表、load order、**同预载集合**、lifetime（禁止 reload）
- [ ] 禁止路径对照（晚加载兄弟段；del→reload）
- [ ] 工厂单例 + `ensure_*_stack` 齐套入口
- [ ] 冷启动冒烟：多模式连续无 IOVA
- [ ] 互斥结论明确；Agent 无自动 reboot
- [ ] 加载门禁与精度门禁分列汇报

## 9. 相关 skills

- 量化与产物门禁：`horizon-bpu-ptq`
- 实验方法：`field-validation-method`
- 远端执行：`remote-ssh-dev`
- 配置沉淀：`author-cursor-config` / `cursor-config-sync`
