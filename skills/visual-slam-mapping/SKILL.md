---
name: visual-slam-mapping
description: >-
  Handheld and robot 2D/3D visual SLAM mapping (RTAB-Map IR stereo, slam_toolbox,
  ORB-SLAM3, depth-to-grid). Use when tuning RealSense mapping, diagnosing map
  smear/double walls/VO_LOST, comparing known%/loops/path-span, or choosing
  geometry vs semantic bypass for white walls and glass.
---

# 纯视觉 / RTAB 建图调优

经验来自手持 RealSense + S100/Go2 实机会话。原则优先于再堆分辨率。

## 1. 先定管线骨架

| 目标 | 优先方案 | 不要做 |
|------|----------|--------|
| 手持 2D 占据图 | `stereo_odometry`(IR1/2+IMU) + `rtabmap`(infra1+depth) | 用 RGB+aligned_depth 当主路径；开 spatial/temporal 深度滤波 |
| 狗端 2D | 写图前做 scan match / pose graph 观测约束 | 开环 odom 直接投影当真图；只看 known% |
| 白墙 / 玻璃 | 几何主图 + 旁路写 `/map_semantic` | 把 seg/mask 喂进 VO 或 RTAB 主通路 |

RealSense 默认：`emitter=0`，手持关深度滤波（保住 IR-Depth exact sync）。

## 2. 参数分家

- VO 节点只收 odom 相关参数。
- Grid / Loop / RGBD 参数只给 rtabmap。
- 灌错会出现大量 `Ignored ...`，并污染跟踪。

## 3. 每会话必记的验收指标

不要只看 known%。

| 指标 | 看什么 |
|------|--------|
| lost% / VO_LOST 时长 | 跟踪是否健康 |
| loops + path/span | 真闭环 vs 假回环（环多但拧弯/双墙 = 假环） |
| no_odom / sync_lag | 传感器与时间同步 |
| 目视 + `map_grid.png` | 房间拓扑是否可认 |

开环投影陷阱：known% 可到 60%+，布局仍是双瓣团块——根因是位姿无约束，不是深度坏。

## 4. 「中好后差」排查顺序

1. 中后段 loops 接近 0 → 漂移 smear → 再 VO 硬失锁（通常不是「图不够大」）。
2. 减负优先于加细：先降 `RangeMax`、提高 `Decimation`，再谈 2.5cm 栅格。
3. LoopThr 过松拧弯，过严无真环；配合走动回访 + ProximityBySpace。
4. 高度带过紧会抹墙（手持不要用过窄 Grid 高程）。

## 5. 失锁策略

| 场景 | 做法 |
|------|------|
| 短失锁 | 可继续建图；按产品需求设 `publish_null_when_lost` |
| 长失锁后继续走动 | 禁止随意 `soft_reset` / `reset_odom`（易米级跳变） |
| 操作侧 | VO_LOST 时停步回纹理区；IMU hold 有时限，撑不住就停扫 |

注意：防跳变不等于能恢复拓图。关 soft_reset 后地图可能停更，需要重锁或可恢复策略。

## 6. 远端快速检查

```bash
ls -lt /root/vln/maps/output/<session>/
ros2 topic hz /odom_vo
ros2 topic hz /scan
```

语义旁路与玻璃占用见 `semantic-occupancy-fusion`。
纯视觉在白墙/满幅玻璃上有物理上限：应改传感/VIO/架构，而不是再调同一 stereo。
