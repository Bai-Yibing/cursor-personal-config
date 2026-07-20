---
name: semantic-occupancy-fusion
description: >-
  Semantic occupancy map fusion with YOLOE/BPU detection and glass heuristics.
  Use when wiring /map_semantic, semantic_occ_fusion, glass_occ_node, mask times
  depth voting, or diagnosing empty semantic diffs, fusion OOM, or white-wall
  and glass holes in 2D maps.
---

# 语义占据旁路融合

几何 `/map` 与语义 `/map_semantic` 解耦。语义只修补穿透/漏检类障碍，**不进 VO**。

## 1. 硬约束（禁止项）

1. **禁止**语义标 free（误 free 比漏检更危险；玻璃后场景会被「合法挖空」）。
2. **禁止**把分割 mask 喂进 stereo/VO（需要可重复点对应；mask 不造特征；开放词汇类表常无 wall/glass）。
3. 写入规则：`mask x 有效深度` -> occupied / unknown；只写表面 hit + 投票。
4. 桌子等实体：表面 hit 会锺空可走 -> 用**实例 footprint**（凸包/MBR）填实，再用 closing 去锯齿。
5. 无分割、低置信度或无效深度 -> **不写入**，也不转发 VO。

## 2. 推荐数据流

```text
RGB/depth + camera_info
    -> YOLOE (BPU)
    -> mask
    -> mask x valid_depth (surface vote)
    -> semantic grid /map_sem_objects
glass_occ (depth-hole heuristic)
    -> merge
    -> /map_semantic
stereo_odometry --> /odom_vo   # geometry only; no seg inject
imu_vo_hold     --> /odom + TF # short hold with timeout
```

若 YOLOE 含 CPU 段或单帧耗时过高：先量队列积压与超时，再决定重导出或调度。

## 3. 验收清单

不要只看「有没有 map_semantic 文件」。

| 检查项 | 方法 / 通过标准 |
|--------|-----------------|
| 融合是否真写了 | `diff(map, map_semantic)` 差分细胞数；约 0 = 旁路空写 |
| 检测是否有效 | cls >= 0、mask 非空、overlay 冒烟图正常 |
| BPU 是否合格 | 有 CPU segment = **不合格**；看 profiler 与端到端 ms |
| 几何是否被拖垂 | 同场 lost% 对比纯几何会话；限制 infer_hz / 绑核 / 带宽 |
| 桌子等实体 | footprint 覆盖桌腿与可碰擞边界，无「锺空走廊」 |

## 4. 常见坑

| 现象 | 处理 |
|------|------|
| fusion `bad_alloc` / length_error | 板端 rclcpp 避免大 string-array 参数，改 **CSV**；检查 map resize 时 vote 缓冲 |
| 「BPU」却约数秒/帧 | profiler 里 **ConvTranspose 落 CPU**；必须全 BPU 重导 |
| policy 写了 wall/glass 却无检出 | 类表与模型不对齐 = 空枪（class policy mismatch） |
| glass hits 上千但差分约 1% | 启发式过猛，普通空洞被当玻璃；先收紧，VO 稳后再 A/B |
| 开 color + BPU 后 lost 升高 | USB/算力争用；控制变量后再比走动 |
| 空语义输入 | 基线地图与 VO 必须不受影响 |

## 5. 玻璃启发式

反射、边缘与空深度会使启发式过触发。用多帧稳定性、视差几何、掩膜面积与最小距离门限反证；无法确认时不写入地图。

## 6. 与纯视觉上限的关系

分割抬的是占据质量（实例 footprint），不是白墙 VO。
位姿需要 VIO / 投影 / 线特征 / 分段策略；见 `visual-slam-mapping`。
