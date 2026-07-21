---
name: semantic-occupancy-fusion
description: >-
  Geometry-semantic decoupled occupancy fusion methodology. Use when wiring
  semantic map layers, mask-depth voting, instance footprint fill, glass or
  hole heuristics, diagnosing empty map diffs despite fusion logs, map-expand
  vote wipes, fusion OOM, or compute contention with the geometry pipeline.
---

# 语义占据融合方法论

几何主图与语义副图解耦。语义只补穿透、漏检类障碍，**不进位姿估计或特征匹配前端**。

## 1. 问题定义

用分割/检测补几何占据的空洞（透明、白墙、细腿/桌面实体）。失败表现：语义层空写、误标可通行、拖尾几何管线、启发式过触发、**日志有 footprint 但落盘仍镂空**、长扫后语义被扩边清票抵消。

## 2. 不变量 / 第一性原理

- **安全不对称**：误标 free 比漏检更危险（会把未知区域合法化为可通行）。
- **外观 ≠ 几何对应**：mask 不提供可重复点对应，不能注入特征 VO。
- **表面 hit vs 体积 footprint**：单点深度可造成「镂空走廊」；实体需底面投影或凸包/MBR 填实，再 morph close 去锯齿。
- **运行时写入 ≠ 持久化成功**：fusion 日志有 cells，不等于最终 map 差分可见。
- **栅格扩边会破坏未 remap 的票**：地图宽高/origin 一变若整表清零投票，长扫 footprint 必虚。
- **VO KPI ≠ 占据 KPI**：lost%/loops 好不等于桌子成块、墙体可导航。
- **启发式需稳定门禁**：玻璃/空洞等必须多帧、几何反证后才写入；过猛 hits 不等于有效差分。

## 3. 架构/选型决策树

```text
RGB/depth + camera_info
  -> detector/segmenter (edge NPU or GPU)
  -> mask
  -> mask x valid_depth (surface vote)
  -> optional instance footprint (convex/MBR fill)
  -> optional morph close on semantic layer
  -> semantic grid layer
heuristic branch (glass / depth-hole)
  -> merge -> semantic map topic
geometry odometry --> pose (geometry only; no mask inject)
map expand --> MUST remap votes/origin; never silent wipe
```

| 场景 | 写入策略 | 禁止 |
|------|----------|------|
| 穿透表面 | occupied 或 unknown | 标 free |
| 桌子等实体 | footprint 填实 + 去锯齿 | 仅单点深度 hit |
| 低置信度 | 不写入 | 转发到 VO |
| 算力竞争 | 限制 infer_hz / 绑核 | 与建图同频无限制跑 |
| 地图扩边 | remap 投票与语义缓冲 | 整表清票无迁移 |
| finalize | 几何/语义同网格同 origin | 网格错位后仍比差分 |

## 4. 标准操作流程 SOP

1. 确认几何管线独立运行且基线指标已记录（位姿表与占据表分开）。
2. 接入语义节点；验证类别表与模型一致。
3. 写入前对每帧做 `mask ∩ valid_depth`；实体类再做 footprint 填实。
4. 启发式分支单独调门限，VO 稳定后再 A/B；一次只开一个变量。
5. **扩边路径**：任何 map 尺寸/origin 变化必须 remap 既有投票；用尺寸变化次数做门禁。
6. 用地图差分验收：`diff(geometry_map, semantic_map)`，并确认宽高/origin 一致。
7. 同场景对比纯几何会话的跟踪丢失率与延迟；语义开启后 VO 不得明显恶化。

## 5. 度量与门禁

| 检查项 | 方法 | 通过标准 |
|--------|------|----------|
| 真写入 | `diff(geometry, semantic)` + 网格对齐 | 差分细胞数 > 0 且符合预期 |
| 检测有效 | cls/mask/overlay 冒烟 | 非空 mask、置信度达标 |
| 实体完整性 | footprint 落盘块状 occupied | 无镂空可走走廊；不只看日志 cells |
| 扩边安全 | 数 map 尺寸变化次数 | 有扩边则投票已 remap，长扫差分不归零 |
| 加速器部署 | profiler / 端到端 ms | 无意外 CPU fallback 段 |
| 几何无拖尾 | 同场 lost% 对比 | 语义开启后不恰好恶化 |
| 启发式 | hits vs 有效差分 | 高 hits + 近零差分 → 过猛/无效 |

**虚荣指标**：fusion 日志 cells、glass hits、文件存在。  
**验收指标**：对齐网格后的 map diff、实体块状度、VO lost%/loops 不退化。

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 差分约 0 | 类别不匹配、空检测、网格错位 | overlay + cls + 宽高/origin |
| 日志有 cells、落盘空 | 扩边清票、finalize 不同网格 | 数尺寸变化；对齐后重 diff |
| 长扫 VO 很好、桌子仍碎 | 占据持久化失败，非扫法 | 短扫对照 + remap 门禁 |
| fusion OOM | 大参数或 resize 缓冲；字符串数组参数踩坑 | 改轻量配置；避板端 string-array declare |
| 数秒级延迟 | 算子落 CPU | profiler 查分段 |
| 启发式爆炸 | 门限过松 | 收紧阈值后重跑 |
| 跟踪恶化 | USB/算力争用 | 单独关语义比对 |
| 分割对、体积镂空 | 仅表面 hit | 上 footprint + closing |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 语义标 free 挖空 | 安全风险 | 只增 occupied/unknown |
| mask 进 VO | 破坏对应 | 严格分流 |
| 看文件/日志 cells 当验收 | 空写或清票无效果 | 对齐网格后 map diff |
| 启发式一帧定案 | 高误报 | 多帧稳定 + 几何反证 |
| VO 好就宣布地图好看 | 两套 KPI | 位姿表与占据表分列 |
| 扩边后整表清票 | 长扫语义归零 | remap 投票 |
| 锯齿靠更细栅格 | 可能更碎 | 先 footprint 再 morph close |

## 8. 交付/复盘检查清单

- [ ] 几何与语义节点解耦；未向 VO 注入 mask
- [ ] 实体类已 footprint；closing 只作用语义层（若启用）
- [ ] 扩边 remap 已实现或本场无扩边
- [ ] finalize 几何/语义同网格；map diff 达标且无误 free
- [ ] 加速器全程在线、无 CPU 意外回退
- [ ] 启发式已记录门限与 A/B；未与其它变量同开
- [ ] 纯几何基线（lost%/loops）未受损

## 9. 相关 skills

- 建图与纯视觉上限：`visual-slam-mapping`
- 边缘 NPU 部署：`horizon-bpu-ptq`
- 导航安全（只增 occupied）：`nav-safety-collision`
- 相机/双目标定：`camera-usb-rgbd`
- 实验方法：`field-validation-method`
