---
name: nav-safety-collision
description: >-
  Layered robot navigation safety and collision diagnosis methodology. Use when
  the robot hits obstacles, explore or coverage gets stuck, scan projection has
  gaps, unknown space is treated as free, or reviewing field-test incident
  timelines.
---

# 导航防撞与碰撞排查方法论

实机撞物多为多层缝隙叠加，很少是单一参数错误。

## 1. 问题定义

移动平台在自主导航、覆盖探索或跟踪中与障碍物发生接触，或误入未知区域。需区分感知漏检、地图误判、决策激进、执行失败与运维监护缺失。

## 2. 不变量 / 第一性原理

- **安全不对称**：未知空间应保守；误通行代价远大于误停。
- **单一里程计不能否认碰撞**：腿式/轮式里程计在接触时可能仍显示小位移。
- **分层防护**：任一层失效都可能导致事故；修复需逐层验证。
- **地图质量影响决策**：高覆盖率不等于拓扑正确（开环投影陷阱）。

## 3. 架构/选型决策树

```text
sense -> map -> decide -> act -> ops
```

| 层 | 关键问题 | 典型缝隙 |
|----|----------|----------|
| 感知 | 障碍是否进入扫描/点云 | 深度投影高度带缝隙 |
| 地图 | unknown 如何处理 | 当成可通行 |
| 决策 | 步长与前沿策略 | step 过大进未知区 |
| 执行 | 局部代价图与速度限制 | 仅依赖实时扫描 |
| 运维 | 急停与监护 | 无人看管长跑 |

## 4. 标准操作流程 SOP

1. **时间线重建**：撞点前后对齐 monitor、地图快照、位姿跳变、速度指令失败、目视记录。
2. **感知层**：检查深度→扫描高度带连续性与视场。
3. **地图层**：unknown 是否被当可通行；footprint/inflation 是否合理。
4. **决策层**：覆盖步长、前沿筛选、失锁停步策略。
5. **执行层**：局部代价图尺寸、静态层、速度上限。
6. **复现试验**：每次只改一层；受控速度与人工监护。
7. 短冒烟通过后再长跑；保留 rollback 标签。

## 5. 度量与门禁

| 指标 | 意义 | 高风险阈值 |
|------|------|------------|
| reloc / pose jump | 碰撞或急停代理 | 跳变显著且与撞点同步 |
| velocity 失败率 | 执行层断链 | 顶障时频繁失败 |
| unknown 通行比例 | 决策激进 | 长步进未映射区 |
| local costmap 尺寸 | 局部障碍反应 | 过小且无 static |
| scan 缝隙 | 细腿漏检 | 高度带不连续 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 撞细腿障碍 | 扫描高度带缝隙 | 可视化投影带 |
| 进未知区撞墙 | unknown 当 free | 查 coverage 策略与 step_m |
| 地图贴边仍撞 | 局部图小无静态 | 扩大 local + 加 static |
| 腿程小但已碰 | 单一里程计误导 | 对齐视频与位姿跳变 |
| 探索卡死 | 失锁或进度失败 | monitor 时间线 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 只调 Nav2 一个参数 | 缝隙在感知/地图 | 分层排查 |
| 用腿程否认碰撞 | 接触时里程计可靠 | 多源时间线 |
| unknown 当可通行加速探索 | 安全风险 | 保守前沿 |
| 多层同时大改 | 无法归因 | 单层 A/B |
| 未做冒烟长跑 | 事故代价高 | 短距离验证 |

## 8. 交付/复盘检查清单

- [ ] 撞点时间线已对齐多源证据
- [ ] 感知→地图→决策→执行各层已排查
- [ ] 单层修复已单独验证
- [ ] 短冒烟通过，rollback 可用
- [ ] 运动前场地安全确认

复盘模板见 `field-validation-method` 之 run_meta；补充字段：scan_gap_suspect、unknown_as_free、one_layer_change。

## 9. 相关 skills

- 建图质量与 known% 陷阱：`visual-slam-mapping`
- 语义只增 occupied：`semantic-occupancy-fusion`
- 实验方法：`field-validation-method`
- 远端取证：`remote-ssh-dev`
