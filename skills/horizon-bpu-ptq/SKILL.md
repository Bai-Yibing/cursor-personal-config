---
name: horizon-bpu-ptq
description: >-
  Edge NPU/BPU post-training quantization and on-device deployment methodology.
  Use when running hb_compile or similar toolchains, packaging HBM or binary
  artifacts, gating CPU fallback segments, tuning PTQ precision, splitting
  unsupported graphs, multi-core scheduling, calibration domain matching, or
  validating on-board latency and task metrics.
---

# 边缘 NPU/BPU 量化与部署方法论

工作路径仅用 `<ptq_workspace>`。编译成功 ≠ 全加速器 ≠ 板端可用 ≠ 任务达标。

## 1. 问题定义

将深度模型部署到嵌入式加速器（NPU/BPU/DSP 等）时的改图、量化、分段、上板与验收。典型失败：算子落 CPU/hybrid、进度 UI 误导、校准域与部署分布错位、敏感层强 fp16 破坏门禁、单点余弦当精度、未做板端 profiling、多任务抢同一编译容器。

## 2. 不变量 / 第一性原理

- **优先级**：全加速器门禁（CPU/hybrid=0）→ 任务精度 → 墙钟速度。不为提速或「敏感层 fp16」牺牲门禁。
- **加速器常驻**：目标子图无意外 CPU/hybrid；否则延迟与确定性不可控。
- **校准域对齐**：校准激活分布须贴近部署（近距视差、真实 latent、真实 RGB）；错域可过门禁却毁掉任务指标。
- **静态图 vs 自回归运行时**：固定 shape 视觉前端可单次推理打包；LLM/VL 动态图用独立 runtime（System1+System2）。
- **板端是真相**：开发机 cosine/编译 latency 不可替代板端墙钟与任务质量。
- **墙钟 ≠ 加速器时间**：全 BPU 后 host/DDR/H2D 仍可占大半；要分段 profile。

## 3. 架构/选型决策树

| 情况 | 路径 | 备注 |
|------|------|------|
| 整图算子全支持 | 单包静态图 | 最简调度 |
| 不支持/易落 CPU 算子 | **先改图**再 PTQ | ScatterND/ConvTranspose/Resize 等；改写为驻留，不指望靠它提精度 |
| 部分图仍过大 | 图拆分 + 主机拼接 | 记录段间 I/O 与调用顺序 |
| 大模型多子系统 | System1(NPU) + System2(LLM runtime) | 不赌单包塞全部 |
| 检测/分割头 | 全加速器；头输出 logits，后处理再 sigmoid | 头层强 fp16 易 `external_cpu` |
| 立体/复杂迭代图 | 多段 HBM + 等价改写 | Feat/Init/Update 等分段独立验收 |
| 多核加速器 | 只给**算力墙**段升 `core_num`；量化配方不变 | 搬数墙段优先减 DDR/复用，勿默认全段双核 |
| 几何采样触顶（深度） | ROI/更高部署分辨率/微调 | PTQ 无法突破 mm/px 几何下限 |

## 4. 标准操作流程 SOP

1. **隔离**：一长编译一容器/一 GPU；并行任务必须换容器换卡。
2. **改图优先**（需要时）：surgery → float 多指标对齐（相对 GPU）再进量化。
3. **校准**：输入分布对齐部署域；禁止「随机 latent + 无关公开图」当精度基线。
4. **编译**：等待**产物落盘** + 成功收尾日志；进度 100% ≠ 完成。中断保留 `.bc`，可跳过校准续编。
5. **门禁**：目标段 CPU=0、无 hybrid；advice/分段报告无意外 `external_cpu`。
6. **主机冒烟**：加载、输入名/shape、段调用顺序。
7. **板端**：BPU 时间与墙钟分开记；任务指标（mAP/EPE/轨迹 ADE·FDE 等）相对基线。
8. **打包**：带时间戳 + rollback；latest 只指向验收包；半成品不覆盖最优交付。

## 5. 度量与门禁

| 门禁项 | 通过标准 |
|--------|----------|
| 产物就绪 | 二进制/HBM 落盘 + 成功日志（不信进度条） |
| 加速器居留 | 目标段 CPU=0、hybrid=0；profiler 无意外 fallback |
| Float 对齐 | 改图后相对 GPU：多指标（cosine / L2 / 任务头）过阈值 |
| 校准域 | 激活落在部署典型区间；held-out 与 calib 同源策略 |
| 延迟 | 板端墙钟满足帧率；同时报告加速器时间与 host/DDR |
| 精度 | **多指标**任务验收；禁止只盯单节点校准 cosine |
| 版本 | 输入名/shape/精度/调用顺序/多核绑定与文档一致 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 进度 100% 无文件 / 收尾挂死 | 异步失败或 HBDK 僵死 | 查日志末尾与产物 mtime；单段重启，不动已完成段 |
| 容器中途退出 | OOM/抢卡/exec 会话断 | 保 `.bc` 续编；查主机 RAM 与 GPU 独占 |
| 加载成功但极慢 | ConvTranspose/Resize/Scatter 等落 CPU | 分段 profiler + advice Device 列 |
| 门禁过但任务指标崩 | 校准域错误；或 kl/头层过激 | A/B 换真实域校准；回退上一配方 |
| 敏感层 fp16 后更慢 | 算子打回 CPU/hybrid | 对照 CPU 段计数；废版 |
| 双核无收益或更慢 | 瓶颈在 DDR；或加载顺序/IOVA | 只核对称量段；先 load 重段再轻段 |
| 近距深度 mm 级无解 | 部署分辨率下视差采样不够 | 算 mm/px 预算；ROI/分辨率/训练，而非加 calib |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 进度条=完成 | UI ≠ 产物 | 检落盘与成功日志 |
| 能加载=可上线 | CPU 段可藏很深 | profiler + 板端指标 |
| 大面积 sensfp16 / 头层强 fp16 | 常破门禁或极慢 | Softmax/LN 等白名单；头保持 int |
| 单点校准 cosine 当验收 | 域错时仍可「看起来还行」 | 多指标 + held-out + 板端任务 |
| 开发机宣布提升 | 温度/带宽/后处理不同 | 必须板端测 |
| 同容器并行长编译 | 抢 GPU/RAM，互相拖死 | 一容器一任务 |
| 为双核改量化配方 | 回到 CPU 慢路径 | 只改 `core_num`/调度 |
| 单包赌大模型 | 图超限 | System1+2 |
| 用实验室远景集校准近距机器人 | 激活分布错位 | 按本机 B/fx 与距离桶建校准 |

## 8. 交付/复盘检查清单

- [ ] 容器/GPU 隔离；路径在 `<ptq_workspace>`
- [ ] 改图 float 多指标对齐（若做过 surgery）
- [ ] 每段 CPU=0、可加载、调用顺序与多核绑定已核对
- [ ] 校准域说明与 held-out 策略已记录
- [ ] 废版备份与 rollback；未覆盖最优基线
- [ ] 板端：加速器时间 + 墙钟 + 任务多指标
- [ ] 汇报标注 `<ptq_host>`、包路径占位符、时间

## 9. 相关 skills

- 实验与置信度：`field-validation-method`
- 语义检测上板：`semantic-occupancy-fusion`
- 远端执行与取材：`remote-ssh-dev`
