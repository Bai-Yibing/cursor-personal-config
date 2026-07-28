---
name: edge-bpu-runtime-iova
description: >-
  Edge NPU/BPU multi-model runtime methodology for IOVA / IOMMU mapping failures,
  load-order contracts, core binding, process isolation, and poisoned accelerator
  state. Use when loading multiple HBMs or packed models, seeing "iova addr not
  equal for different core", false "model corrupted" errors, ASR/TTS/vision
  segments failing to load after another model ran, dual-core scheduling, or
  designing board smoke / web pipelines that share one SoC.
---

# 边缘加速器多模型运行时（IOVA / 加载序）

适用于在同一 SoC 上先后或同时加载多个加速器模型包（HBM / 分段图 / AR leap 等）时的运行时契约。目标：**从根上避免映射表被打乱**，而不是每次毒化后靠重启碰运气。

## 1. 问题定义

多模型上板常见失败：

- 单模可加载，第二模加载报 IOVA / IOMMU 不一致
- 日志写「模型损坏 / lib 需升级」，实为映射冲突的次生文案
- 进程退出后新进程仍无法加载，直至整机重启
- 评测脚本「先单测 A 再同进程测 A+B」把板端毒化，掩盖任务精度结论
- 两路业务抢同一 BPU 核（如 Codec 与 Decoder 同核）导致串场

本 skill 管**加载、绑核、进程边界、毒化恢复**；量化精度见 `horizon-bpu-ptq`，实验置信度见 `field-validation-method`。

## 2. 不变量 / 第一性原理

1. **映射表是全局稀缺状态**：主机物理页 ↔ 各核 IOVA 一经建立，错误的二次加载会弄乱表；进程结束≠表已干净。
2. **加载序是契约，不是风格**：能共存的组合必须写成「先谁后谁 / 是否允许推理穿插」；未验证的序默认禁止。
3. **同进程常驻模型集合要一次定好**：需要同进程使用的模型，在**任何推理之前**全部加载并绑核；禁止「先跑 A 再晚加载 B」。
4. **核是预算不是装饰**：每个常驻模型有明确 core 集合；冲突核上的业务只能**分时 + 分进程**，且须验证跨进程是否仍毒化。
5. **毒化后唯一可靠恢复往往是冷启动**：Agent **不得擅自 reboot**；向用户说明原因并请其重启；重启前不要继续堆加载试验。
6. **虚荣 ≠ 可用**：单模 load OK、文件 md5 对、日志无 traceback，都不能证明多模会话安全。

## 3. 架构 / 选型决策树

```text
要在板上跑 ≥2 个加速器模型？
  ├─ 必须同进程（低延迟流水）？
  │     ├─ 已有验证过的 preload 序 + 分核表？ → 严格按契约：全 preload → 再推理
  │     └─ 没有？ → 先做最小对照（见 SOP），再写进 configs，禁止直接上 Web
  ├─ 可分进程？
  │     ├─ 验证「A 进程退出后 B 能否加载」→ 能：分进程编排
  │     └─ 不能（跨进程毒化）→ 当作互斥会话；中间要用户冷启动，或合并为同进程 preload
  └─ 与常驻服务（检测/其它 daemon）抢核？
        → 给业务预留空闲核；不要默认 kill 常驻服务；核表写入配置并文档化
```

| 模式 | 何时用 | 约束 |
|------|--------|------|
| 同进程全 preload | ASR enc+dec、视觉多段常驻 | 推理前加载完；核互不覆盖或已验证可共享 |
| 同进程有序释放 | A 跑完 unload 再 load B（若 runtime 支持真释放） | 须用「再 load」实验证明释放有效；很多栈上 `del` 不够 |
| 分进程互斥 | TTS 与 ASR 无法安全共会话 | 一次会话一种管线；切换前确认未毒化或冷启动 |
| Codec / 重段优先 | 解码器或大包对映射更敏感 | 先加载更「重」或更易碎的段（以板上对照为准） |

## 4. 标准操作流程 SOP

### 4.1 设计阶段（上板前）

1. 列出会话内**全部**加速器产物与角色（前端 / AR / Codec / 后段）。
2. 画 **core 预算表**（含其它 daemon 占用）。
3. 为每条产品路径写死 **load order**（示例形态：`Codec → Talker`；`Enc+Dec preload → infer`；`Feat → Init`）。
4. 把序与核表放进仓库配置（如 `bpu_cores.json`），禁止只活在聊天记录里。

### 4.2 冒烟阶段（短、可回滚）

1. 冷启动后**只**跑「契约路径」最小用例（一次 preload + 一次推理）。
2. 再跑「禁止路径」对照（先单模推理再加载第二模）——预期失败则记入文档，不要当评测主路径。
3. 分进程：A 结束后立刻开 B；若 B 失败 → 标为**跨进程毒化**，会话互斥。
4. 通过后才允许 Web / 长评测接入。

### 4.3 评测阶段

1. **每个会毒化的 stage 独立进程**；会毒化的顺序不要串在同进程。
2. 需要同进程多模的 E2E：进程内**禁止**先跑 encoder-only / talker-only 再 dual-load。
3. 毒化后停止加测，请用户冷启动；不要用「再试一次加载」污染结论。

### 4.4 Agent 行为

- 发现 IOVA / 「model corrupted」且伴随多核地址不一致 → 按本 skill 定性，**不要**当文件坏了重传糊弄。
- **禁止**未经用户明确要求执行 `reboot` / `shutdown`。
- 汇报写清：主机角色、核表、加载序、是否已毒化、是否待用户重启。

## 5. 度量与门禁

| 类型 | 虚荣 | 验收 |
|------|------|------|
| 加载 | 单模 `HB_HBMRuntime` 成功 | 契约路径下多模 preload + 推理成功 |
| 序 | 「我们觉得应该先 A」 | 对照：违规序稳定复现失败；合规序稳定成功 |
| 核 | 配置文件里写了 cores | 与板上 `set_scheduling_params` / 实测一致；与 daemon 不撞车 |
| 恢复 | 进程 kill 了 | 新进程可加载 **或** 明确标注必须冷启动 |
| 任务 | 毒化板上碰巧出了一次文本/音频 | 冷启动 + 契约路径下的多条样本任务指标 |

未定义「合规加载序」的试验，**不得**用于发布「多模可用」结论。

## 6. 故障分类学

| 症状 | 可能原因 | 否证 / 处置 |
|------|----------|-------------|
| `iova addr not equal for different core` | 二次加载时多核 IOVA 表不一致 | 冷启动后只走契约 preload；对比违规序 |
| `Hbm file is corrupted` / `libhbrt* needs update` 但 md5 未变 | 次生误报 | 先当 IOVA；冷启动后同文件能加载即证实 |
| 同进程：A 推理后 load B 失败 | 晚加载 / 同核冲突 | preload 两者再推理；或分核 |
| 新进程也 load 失败 | 跨进程毒化 | 标互斥会话；请用户冷启动；停止继续加载 |
| ASR 后 TTS（或反向）失败 | 共享核上的 Codec↔Decoder 等 | 核预算重排或会话互斥 |
| 仅双核模型失败、单核成功 | 多核映射更脆 | 降核验证；或固定加载序 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 评测同进程「先单模再组合」 | 必踩晚加载，毒化板端 | E2E 独立进程且只 preload |
| `del rt` / 子进程退出当重置 | 映射常留在驱动/固件 | 用实验证明；否则冷启动 |
| 两业务默认同核「省事」 | 串场与毒化 | 核预算表；冲突则互斥 |
| 把 corrupted 当文件坏了反复 scp | 浪费时间、掩盖真因 | md5 + 冷启动对照 |
| Agent 自行 reboot | 打断用户、藏毒化证据 | 说明原因，请用户重启 |
| Web 默认打开未验证多模路径 | 现场「兹拉 / 乱码」 | 契约未过门禁不下线开放入口 |
| 只修解码后处理忽略加载契约 | 循环可挡，加载仍挂 | 运行时契约与精度修复分开做 |

## 8. 交付 / 复盘清单

- [ ] 产品路径写明：模型列表、core 表、load order、是否允许同进程
- [ ] 禁止路径有一条对照记录（失败可接受，但须文档化）
- [ ] 冒烟在冷启动后复现通过
- [ ] 跨进程毒化结论明确（可共存 / 须互斥 / 须冷启动）
- [ ] Agent/脚本：**无**自动 reboot；毒化时停测并提示用户
- [ ] 与 `horizon-bpu-ptq` 精度门禁分开汇报（加载成功 ≠ 任务达标）

## 9. 相关 skills

- 量化与产物门禁：`horizon-bpu-ptq`
- 实验方法：`field-validation-method`
- 远端执行：`remote-ssh-dev`
- 配置沉淀：`author-cursor-config` / `cursor-config-sync`
