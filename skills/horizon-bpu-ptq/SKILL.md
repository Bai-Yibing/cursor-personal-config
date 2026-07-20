---
name: horizon-bpu-ptq
description: >-
  Edge NPU/BPU post-training quantization and on-device deployment methodology.
  Use when running hb_compile or similar toolchains, packaging HBM or binary
  artifacts, gating CPU fallback segments, tuning PTQ precision, splitting
  unsupported graphs, or validating on-board latency and task metrics.
---

# 边缘 NPU/BPU 量化与部署方法论

工作路径仅用 `<ptq_workspace>`。编译成功 ≠ 板端可用 ≠ 任务达标。

## 1. 问题定义

将深度模型部署到嵌入式加速器（NPU/BPU/DSP 等）时的量化、分段、上板与验收。典型失败：算子落 CPU、进度 UI 误导、整图不支持却未拆分、精度配方破坏检测头、未做板端 profiling 就宣称「全加速器」。

## 2. 不变量 / 第一性原理

- **加速器常驻算子门禁**：目标子图必须无意外 CPU/hybrid 段；否则延迟与确定性不可控。
- **静态图 vs 自回归运行时**：固定 shape 的视觉前端可打包为单次推理；LLM/VL 级动态图需独立运行时（远端 GPU 或专用 runtime）。
- **精度手段有边界**：敏感层强制低精度可能把算子打回 CPU 或破坏头部。
- **板端是真相**：开发机指标不可替代板端延迟与任务质量。

## 3. 架构/选型决策树

| 情况 | 路径 | 备注 |
|------|------|------|
| 整图算子全支持 | 单包静态图 | 最简调度 |
| 部分算子不支持 | 图拆分 + 主机拼接 | 记录段间 I/O 与顺序 |
| 大模型多子系统 | System1(NPU 固定前端) + System2(LLM runtime) | 不赌单包塞全部 |
| 检测/分割头 | 全加速器 + 后处理验证 | 可加载 ≠ 类别布局正确 |
| 立体视觉等复杂图 | 多段 HBM + 算子等价改写 | 改写为了部署而非提精度 |

## 4. 标准操作流程 SOP

1. 隔离容器/GPU 环境；输入校准数据与图输入一致。
2. 导出静态图；记录不支持算子列表。
3. 运行编译工具链（如 hb_compile 等）；等待**产物落盘**与成功收尾日志，不信进度条。
4. 查分段报告：CPU segment = 0，无 hybrid。
5. 主机端冒烟加载与接口顺序。
6. 板端 profiling：延迟、带宽、任务指标（检测 mAP、深度 EPE、轨迹误差等）。
7. 打带时间戳包与 rollback 标签；latest 指向验收包。

## 5. 度量与门禁

| 门禁项 | 通过标准 |
|--------|----------|
| 产物就绪 | 二进制/HBM 落盘 + 成功日志 |
| 加速器居留 | 目标段 CPU=0，profiler 无意外 fallback |
| 延迟 | 板端墙钟 ms 满足帧率预算 |
| 精度 | 任务指标相对基线不回退（须板上测） |
| 版本 | 输入名/shape/精度/调用顺序与文档一致 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 进度 100% 无文件 | 异步失败未报 | 查编译日志末尾 |
| 加载成功但极慢 | ConvTranspose 等落 CPU | profiler 分段 |
| 精度崩坏 | kl/敏感层 fp16 过激 | 回退上一配方 A/B |
| 整图 export 失败 | 不支持算子 | 拆分或等价改写 |
| 「能编译」但上板挂 | 动态 shape / 内存 | 板端最小用例单独跑 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 进度条=完成 | UI 不等于产物 | 检落盘与日志 |
| 能加载=可上线 | CPU 段可能难察觉 | profiler + 板端指标 |
| 敏感层强 fp16 必提精度 | 常打回 CPU | 分段验证 |
| 开发机宣布提升 | 温度/带宽不同 | 必须板端测 |
| 单包赌大模型 | 图超限 | 拆 System1+2 |

## 8. 交付/复盘检查清单

- [ ] 容器/GPU 隔离，路径在 `<ptq_workspace>`
- [ ] 每段 CPU=0、可加载、调用顺序已核对
- [ ] 废版备份与 rollback 标签
- [ ] 板端 latency + 任务指标已测
- [ ] 汇报标注 `<ptq_host>` 与包路径、时间

## 9. 相关 skills

- 语义检测上板：`semantic-occupancy-fusion`
- 实验与置信度标签：`field-validation-method`
- 远端执行：`remote-ssh-dev`
