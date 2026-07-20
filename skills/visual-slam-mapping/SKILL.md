---
name: visual-slam-mapping
description: >-
  Handheld and robot 2D/3D visual SLAM mapping (RTAB-Map IR stereo, slam_toolbox,
  ORB-SLAM3, depth-to-grid). Use when tuning RGB-D mapping, diagnosing map
  smear/double walls/VO_LOST, comparing known%/loops/path-span, or choosing
  geometry vs semantic bypass for white walls and glass.
---

# 纯视觉 / RTAB 建图调优

原则优先于再堆分辨率。产物只写入 `<maps_output>/<session>/`。

## 1. 先定管线骨架

| 目标 | 优先方案 | 不要做 |
|------|----------|--------|
| 手持 2D 占据图 | `stereo_odometry`(IR1/2+IMU) + `rtabmap`(infra1+depth) | RGB+aligned_depth 当主路径；开 spatial/temporal 深度滤波 |
| 机器端 2D | 写图前做 scan match / pose graph 观测约束 | 开环 odom 直接投影当真图；只看 known% |
| 白墙 / 玻璃 | 几何主图 + 旁路写 `/map_semantic` | 把 seg/mask 喂进 VO 或 RTAB 主通路 |

默认：`emitter=0`；手持关深度滤波（保住 IR-Depth exact sync）。

骨架要点：

1. IR stereo + IMU 做 VO（跟踪与位姿）。
2. infra + depth 进 rtabmap 做栅格与闭环。
3. 时间戳、外参、分辨率与标定必须一致后再调参。

## 2. 参数分家（VO vs rtabmap）

- VO 节点只收 odom / 跟踪相关参数。
- Grid / Loop / RGBD / 建图参数只给 rtabmap。
- 灌错会出现大量 `Ignored ...` 日志，并污染跟踪 -- 把 Ignored 当硬失败信号。

## 3. 每会话必记指标

不要只看 known%。known% 高 != 布局正确。

| 指标 | 看什么 | 异常时首查 |
|------|--------|------------|
| lost% / VO_LOST 时长 | 跟踪是否健康 | 纹理、曝光、同步、运动 |
| loops | 真闭环数量与质量 | 走环路线、重叠观测 |
| path/span | 路径空间跨度与尺度 | 尺度漂移、断链 |
| known% | 覆盖率（辅助） | 投影/深度有效性；**不可单独验收** |
| no_odom / sync_lag | 传感器与时间同步 | 驱动、USB、时钟 |

开环投影陷阱：开环 odom 投影可使 known% 到 60%+，布局仍是双瓣团块 -- 根因是位姿无约束，不是深度坏。开环投影只作诊断，不作地图或导航验收证据。

## 4. 「中好后差」排查顺序

1. 中后段 loops 接近 0 -> 漂移 smear -> 再 VO 硬失锁（通常不是「图不够大」）。
2. 减负优先于加细：先降 `RangeMax`、提高 `Decimation`，再谈更细栅格。
3. LoopThr 过松拂弯，过严无真环；配合走动回访 + ProximityBySpace。
4. 高度带过紧会抹墙（手持不要用过窄 Grid 高程）。
5. 按时间轴对齐 lost、回调频率、曝光/温度变化与闭环事件，禁止一上来大改一堆参数。

## 5. 失锁与 soft_reset

| 场景 | 做法 |
|------|------|
| 短失锁 | 可继续建图；按产品需求设 `publish_null_when_lost` |
| 长失锁后继续走动 | **禁止**随意 `soft_reset` / `reset_odom`（易米级跳变） |
| 操作侧 | VO_LOST 时停步回纹理区；IMU hold 有时限，撑不住就停扫 |

注意：防跳变不等于能恢复拓图。关 soft_reset 后地图可能停更 -- 不要边走边 reset。

## 6. 算法选型权衡

| 方案 | 强项 | 限制 |
|------|------|------|
| ORB + depth_to_grid | 快速定位与深度栅格 | 地图优化弱；易受纹理/标定影响 |
| slam_toolbox | 2D 激光建图与导航衔接 | 依赖稳定 laser/odom |
| RTAB-Map | 多传感器建图与闭环 | 需调好前端与资源；参数分家严格 |

白墙/满幅玻璃：纯视觉有物理上限 -- 应改传感/VIO/架构或走语义旁路，而不是再调同一 stereo。

## 7. 走动 SOP

1. 慢起步，前视野保留纹理；勿快速转身。
2. 沿可重复路径回到起点，主动回访做环。
3. 导出 lost/loops/path-span/known% 与环境事件日志到 `<maps_output>/<session>/`。
4. 验收看闭环后墙体一致性与可导航性，不看单次 known%。

## 8. 远程快速检查

```bash
ls -lt <maps_output>/<session>/
ros2 topic hz /odom_vo
ros2 topic hz /scan
```

语义旁路与玻璃占用见 `semantic-occupancy-fusion`。
