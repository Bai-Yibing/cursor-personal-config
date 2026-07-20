---
name: horizon-bpu-ptq
description: >-
  Horizon/D-Robotics S600 BPU PTQ and multi-HBM deployment (FoundationStereo,
  InternNav/DualVLN, YOLOE). Use when hb_compile, HBM packaging, CPU-segment
  gates, calib/kl/fp16 recipes, OELLM/leap_llm, or on-board latency/EPE checks.
---

# Horizon S600 BPU 量化与上板

开发机编译成功，不等于板上精度/时延已验证。

## 1. 总原则

1. 全 BPU 门禁：目标段 `ON=CPU=0` 且无 hybrid；以 HBM 落盘 + compile 成功日志为准（进度条 100% 不等于完成）。
2. 有 CPU segment = 废版（即使能量化加载）；上线前看 profiler 与端到端毫秒数。
3. 大模型不要赌单 HBM：整模失败就拆段 + 主机调度，或 System1(HBM) + System2(LLM runtime)。
4. 校准手段会伤头：`kl` / 敏感层强制 fp16 可能破坏门禁或检测头；改配方时保留带时间戳的回退包。

## 2. FoundationStereo（多段）

- 整模常因 3D Resize 等不支持算子在 export 失败 → 拆成 Feat / Init / Update / Context 多段 HBM。
- hybrid（如 depthwise Conv3d）优先做算子等价改写（Reshape + Mul + ReduceSum），不指望靠改写提 EPE。
- 精度手段（calib 景数、kl、Softmax fp16）与速度手段（host 常量 pack）分开记账。
- 板上 EPE / 墙钟未测前，不宣称精度提升。

## 3. InternNav / DualVLN

| 组件 | 上板策略 |
|------|----------|
| System1（约 90M，固定 shape） | OE `hb_compile` → HBM |
| System2（Qwen2.5-VL 级） | OELLM / `leap_llm` 或远端 GPU；不能塞进单次静态 OE |
| 敏感 MatMul 强 fp16（sensfp16） | 易把 BPU 算子打成 ON=CPU，精度几乎不涨 → 作废方向 |

校准条数 / 混合 latent 可能把 trajectory cosine 打崩；过门禁后仍要看任务指标。

## 4. YOLOE 等检测分割

- 导出可加载不等于后处理/类布局正确；冒烟检查 cls、mask。
- ConvTranspose 落 CPU 会导致数秒每帧；全 BPU 重编才是在线前提。

## 5. 交付检查清单

- [ ] 容器 / GPU 与任务隔离（避免 FS 与 InternNav 抢同一卡）
- [ ] yaml：`input_type_rt` / `cal_data_dir` 数量与图输入一致
- [ ] 每段记录：CPU=0、HBM 路径、编译 latency
- [ ] 废版备份；latest 软链指向验收包
- [ ] 板端实测：latency + 任务指标（EPE / det / traj cosine），不只看开发机

## 6. 材料标注

汇报写清：`主机 | 容器 | 任务名 | 包路径 | 时间`。
常见产物目录按当日环境填写（如 `/mnt/data/horizon_ptq/`）。
