---
name: edge-bpu-runtime-iova
description: >-
  Edge NPU/BPU multi-model runtime methodology for IOVA / IOMMU mapping failures,
  load-order contracts, lifetime caching of runtimes, core binding, process
  isolation, and poisoned accelerator state. Use when loading multiple HBMs or
  packed models, seeing "iova addr not equal for different core", false "model
  corrupted" errors after a successful earlier load, ASR/TTS/vision segments
  failing after another model ran or after del+reload, dual-core scheduling,
  multi-mode board smoke (A/B/C), or designing pipelines that share one SoC.
---

# 边缘加速器多模型运行时（IOVA / 加载序）

适用于在同一 SoC 上先后或同时加载多个加速器模型包（HBM / 分段图 / AR leap 等）时的运行时契约。目标：**从根上避免映射表被打乱**，而不是每次毒化后靠重启碰运气。

## 1. 问题定义

多模型上板常见失败：

- 单模可加载，第二模加载报 IOVA / IOMMU 不一致
- 日志写「模型损坏 / lib 需升级」，实为映射冲突的次生文案
- **同会话内**先成功加载/推理，`del` 或重新 `HB_HBMRuntime(...)` 后再加载失败，并毒化整机
- 进程退出后新进程仍无法加载，直至整机重启
- 评测脚本「先单测 A 再同进程测 A+B」或「A→C→B 中途卸载重载」把板端毒化
- 两路业务抢同一 BPU 核（如 Codec 与 Decoder 同核）导致串场

本 skill 管**加载、绑核、实例生命周期、进程边界、毒化恢复**；量化精度见 `horizon-bpu-ptq`，实验置信度见 `field-validation-method`。

## 2. 不变量 / 第一性原理

1. **映射表是全局稀缺状态**：主机物理页 ↔ 各核 IOVA 一经建立，错误的二次加载会弄乱表；进程结束≠表已干净。
2. **加载序是契约，不是风格**：能共存的组合必须写成「先谁后谁 / 是否允许推理穿插」；未验证的序默认禁止。
3. **同进程常驻集合要一次定好**：需要同进程使用的模型，在**任何推理之前**全部加载并绑核；禁止「先跑 A 再晚加载 B」。
4. **已加载实例是热资源**：默认 **缓存到进程结束**；`del rt` / 每次调用 `new Runtime(hbm)` **不等于**安全卸载，常导致「第二次加载」毒化。
5. **核是预算不是装饰**：每个常驻模型有明确 core 集合；冲突核上的业务只能**互斥会话**（分时且验证跨进程是否仍毒化）。
6. **毒化后唯一可靠恢复往往是冷启动**：Agent **不得擅自 reboot**；向用户说明原因并请其重启；重启前不要继续堆加载试验。
7. **虚荣 ≠ 可用**：单模 load OK、文件 md5 对、上一模式刚成功，都不能证明下一模式可再 load。

## 3. 架构 / 选型决策树

```text
要在板上跑 ≥2 个加速器模型？
  ├─ 必须同进程（低延迟流水 / 多模式一次跑完）？
  │     ├─ 已有验证过的 preload 序 + 分核表？
  │     │     → 会话开始全 preload（或按序首次加载）并缓存实例
  │     │     → 模式切换只复用，禁止 del/reload
  │     └─ 没有？ → 先做最小对照（见 SOP），再写进 configs，禁止直接上 Web
  ├─ 可分进程？
  │     ├─ 验证「A 进程退出后 B 能否加载」→ 能：分进程编排
  │     └─ 不能（跨进程毒化）→ 互斥会话；中间要用户冷启动
  ├─ 多模式评测（A/B/C/gate）？
  │     ├─ 同 boot 跑多种 → 所有模式用到的模型在首次需要前加载并常驻
  │     └─ 无法常驻 → 每模式独立冷启动（贵，但安全）
  └─ 与常驻服务抢核？
        → 预留空闲核；不要默认 kill 常驻服务；核表写入配置
```

| 模式 | 何时用 | 约束 |
|------|--------|------|
| 同进程全 preload + 缓存 | ASR enc+dec、TTS Codec+Talker+MTP、视觉多段 | 推理前加载完；实例不销毁 |
| 同进程有序释放 | 仅当实验证明 unload 后可再 load | 多数 HBRT 栈上 **`del` 不够**；默认当作不可用 |
| 分进程互斥 | TTS ↔ ASR 等共享核业务 | 一次 boot 一种管线 |
| 重段 / Codec 优先 | 解码器或大包对映射更敏感 | 先加载更易碎段（以板上对照为准） |

## 4. 标准操作流程 SOP

### 4.1 设计阶段（上板前）

1. 列出会话内**全部**加速器产物与角色（前端 / AR / Codec / 后段）。
2. 画 **core 预算表**（含其它 daemon）。
3. 写死 **load order** 与 **lifetime**（示例：`Codec → Talker/MTP 缓存`；`Enc+Dec preload → infer`；`Feat → Init`）。
4. 工厂 API：`_talker()` / `_mtp()` / `_encoder()` 必须返回**单例缓存**，禁止每次 `EmbedsLanguageHBM(path)`。
5. 配置落盘（如 `bpu_cores.json`、`bpu_session_contract.json`），禁止只活在聊天里。

### 4.2 冒烟阶段（短、可回滚）

1. 冷启动后只跑「契约路径」最小用例（preload/缓存 + 一次推理）。
2. 对照「禁止路径」：先单模推理再晚加载；或 load→infer→`del`→再 load——预期失败则写入文档。
3. 分进程：A 结束后立刻开 B；若 B 失败 → **跨进程毒化**，会话互斥。
4. 通过后才允许 Web / 长评测。

### 4.3 评测阶段

1. 会毒化的 stage：**分进程**或**同进程但零卸载**。
2. 同进程多模 E2E：禁止 encoder-only→dual-load；禁止模式间 `del talker/mtp`。
3. 出现 IOVA / 假 corrupted → **立即停测**，请用户冷启动；不要「再试一次加载」。

### 4.4 Agent 行为

- IOVA 或「corrupted」且多核地址不一致 → 按本 skill 定性，**不要**当文件坏了重传。
- 同会话上一模式刚成功、下一模式 load 失败 → 优先查 **reload/lifetime**，不是 HBM 坏了。
- **禁止**未经用户明确要求 `reboot` / `shutdown`。
- 汇报：主机角色、核表、加载序、是否已毒化、是否待用户重启。

## 5. 度量与门禁

| 类型 | 虚荣 | 验收 |
|------|------|------|
| 加载 | 单模 Runtime 成功 | 契约路径下多模 preload/缓存 + 推理成功 |
| 生命周期 | 「我们 del 了应该释放了」 | 对照：del 后再 load 失败则禁止该模式 |
| 多模式 | A、C 各自偶尔成功 | 同 boot 按契约连续 A→C→B（或文档化每模式冷启动） |
| 核 | 配置写了 cores | 与板上调度一致；冲突业务标互斥 |
| 恢复 | 进程 kill 了 | 新进程可加载 **或** 明确须冷启动 |
| 任务 | 毒化板上碰巧出音/字 | 冷启动 + 契约路径多条样本指标 |

未定义合规加载序与 lifetime 的试验，不得发布「多模可用」。

## 6. 故障分类学

| 症状 | 可能原因 | 否证 / 处置 |
|------|----------|-------------|
| `iova addr not equal for different core` | 二次加载时多核 IOVA 不一致 | 冷启动 + 契约路径；对比违规序 |
| `Hbm corrupted` / `libhbrt* update` 但 md5 未变 | 次生误报 | 当 IOVA；冷启动后同文件能加载即证实 |
| A/C 成功，同进程 B load MTP/Talker 失败 | 模式间 `del` 或每次 new Runtime | 缓存实例；禁止 reload |
| 同进程：A 推理后 load B 失败 | 晚加载 / 同核冲突 | 全 preload 再推理；或分核 |
| 新进程也 load 失败 | 跨进程毒化 | 互斥会话；请用户冷启动；停测 |
| ASR 后 TTS（或反向）失败 | 共享核 Codec↔Decoder / AR | 核预算或会话互斥 |
| 仅双核模型失败、单核成功 | 多核映射更脆 | 降核验证；固定加载序 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 每次 `_talker()` new 一个 Runtime | 第二次构造=二次加载 | 进程内单例缓存 |
| 模式结束 `del talker, mtp; gc.collect()` | 映射未真正安全释放 | 保持常驻到进程结束 |
| 同进程「先单模再组合」 | 晚加载毒化 | 开场 preload 或分会话 |
| 同 boot 连跑 ASR 又跑 TTS | 共享核跨进程毒化 | 互斥；中间用户冷启动 |
| 把 corrupted 当文件坏了反复 scp | 掩盖真因 | md5 + 冷启动对照 |
| Agent 自行 reboot | 打断用户、藏证据 | 说明原因，请用户重启 |
| Web 默认未验证多模路径 | 现场噪声/乱码 | 契约过门禁再开放 |
| 只修解码后处理忽略加载契约 | 循环可挡，加载仍挂 | 运行时与精度分开做 |

## 8. 交付 / 复盘清单

- [ ] 产品路径：模型列表、core 表、load order、**实例 lifetime（缓存/禁止 reload）**
- [ ] 禁止路径有对照记录（含 del→reload）
- [ ] 工厂 API 已单例化；代码审出无「每次 new HBM runtime」
- [ ] 冒烟在冷启动后复现通过
- [ ] 跨进程毒化结论明确（可共存 / 须互斥 / 须冷启动）
- [ ] Agent/脚本：无自动 reboot；毒化停测并提示用户
- [ ] 与 `horizon-bpu-ptq` 精度门禁分开汇报

## 9. 相关 skills

- 量化与产物门禁：`horizon-bpu-ptq`
- 实验方法：`field-validation-method`
- 远端执行：`remote-ssh-dev`
- 配置沉淀：`author-cursor-config` / `cursor-config-sync`
