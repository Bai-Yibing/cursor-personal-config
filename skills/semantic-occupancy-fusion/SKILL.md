---
name: semantic-occupancy-fusion
description: >-
  Geometry-semantic decoupled occupancy fusion methodology. Use when wiring
  semantic map layers, mask-depth voting, glass or hole heuristics, diagnosing
  empty map diffs, fusion OOM, or compute contention with the geometry pipeline.
---

# 语义占据融合方法论

几何主图与语义副图解耦。语义只补穿透、漏检类障碍，**不进位姿估计或特征匹配前端**。

## 1. 问题定义

用分割/检测补几何占据的空洞（透明、白墙、细腿障碍）。失败表现：语义层空写、误标可通行、拖尾几何管线、或启发式过触发。

## 2. 不变量 / 第一性原理

- **安全不对称**：误标 free 比漏检更危险（会把未知区域合法化为可通行）。
- **外观 ≠ 几何对应**：mask 不提供可重复点对应，不能注入特征 VO。
- **表面 hit vs 体积 footprint**：单点深度可造成「锺空走廊」；实体需底面投影或凸包填实。
- **启发式需稳定门禁**：玻璃/空洞等启发式必须多帧、几何反证后才写入。

## 3. 架构/选型决策树

```text
RGB/depth + camera_info
  -> detector/segmenter (edge NPU or GPU)
  -> mask
  -> mask x valid_depth (surface vote)
  -> semantic grid layer
heuristic branch (glass / depth-hole)
  -> merge -> semantic map topic
geometry odometry --> pose (geometry only; no mask inject)
```

| 场景 | 写入策略 | 禁止 |
|------|----------|------|
| 穿透表面 | occupied 或 unknown | 标 free |
| 桌子等实体 | footprint 填实 + 去锯齿 | 仅单点深度 hit |
| 低置信度 | 不写入 | 转发到 VO |
| 算力竞争 | 限制 infer_hz / 绑核 | 与建图同频无限制跑 |

## 4. 标准操作流程 SOP

1. 确认几何管线独立运行且基线指标已记录。
2. 接入语义节点；验证类别表与模型一致。
3. 写入前对每帧做 `mask ∩ valid_depth`。
4. 启发式分支单独调门限，VO 稳定后再 A/B。
5. 用地图差分验收，不看文件是否存在。
6. 同场景对比纯几何会话的跟踪丢失率与延迟。

## 5. 度量与门禁

| 检查项 | 方法 | 通过标准 |
|--------|------|----------|
| 真写入 | `diff(geometry_map, semantic_map)` | 差分细胞数 > 0 且符合预期 |
| 检测有效 | cls/mask/overlay 冒烟 | 非空 mask、置信度达标 |
| 加速器部署 | profiler / 端到端 ms | 无意外 CPU fallback 段 |
| 几何无拖尾 | 同场 lost% 对比 | 语义开启后不恰好恶化 |
| 实体完整性 | footprint 覆盖 | 无锺空走廊 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 差分约 0 | 类别不匹配、空检测 | 看 overlay 与 cls 分布 |
| fusion OOM | 大参数或 resize 缓冲 | 改轻量配置、缩小 map |
| 数秒级延迟 | 算子落 CPU | profiler 查分段 |
| 启发式爆炸 | 门限过松 | 收紧阈值后重跑 |
| 跟踪恶化 | USB/算力争用 | 单独关语义比对 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 语义标 free 挖空 | 安全风险 | 只增 occupied/unknown |
| mask 进 VO | 破坏对应 | 严格分流 |
| 看文件存在当验收 | 空写可能无效果 | 地图 diff |
| 启发式一帧定案 | 高误报 | 多帧稳定 + 几何反证 |

## 8. 交付/复盘检查清单

- [ ] 几何与语义节点解耦
- [ ] 未向 VO 注入 mask
- [ ] 地图 diff 达标且无误 free
- [ ] 加速器全程在线、无 CPU 意外回退
- [ ] 启发式已记录门限与 A/B 结果
- [ ] 纯几何基线未受损

## 9. 相关 skills

- 建图与纯视觉上限：`visual-slam-mapping`
- 边缘 NPU 部署：`horizon-bpu-ptq`
- 导航安全（只增 occupied）：`nav-safety-collision`
- 实验方法：`field-validation-method`
