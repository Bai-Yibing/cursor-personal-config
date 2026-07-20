---
name: nav-safety-collision
description: >-
  Robot navigation collision diagnosis and layered safety (depth-to-scan gaps,
  coverage treating unknown as free, Nav2 costmap, reloc jumps). Use when the
  robot hits obstacles, explore/coverage stuck, velocity POST failures, or
  reviewing field-test collision logs.
---

# 导航防撞与撞物排查

实机撞物多为系统性缝隙，很少是单一「Nav2 配错」。

## 1. 典型根因组合

```text
depth -> scan height bands have gaps     -->  thin obstacles miss /scan
coverage/explore treats unknown as free  -->  long steps into unmapped frontier
Nav2 local costmap too small, no static  -->  relies only on live /scan
large visual reloc jump                  -->  strong proxy for collision / e-stop
```

四者常叠加；不要只修其中一层。

## 2. 排查时间线（远端证据）

1. **时间对齐**：撞点前后的 monitor（vx、goal、known）、map 快照、tracking_events / reloc jump、用户目视。
2. **感知**：`depth_to_scan` 高度带是否连续；带间是否漏桌腿/墙缘。
3. **决策**：coverage 是否允许 unknown 通行；`step_m` 是否过大（>= 1.5m 高风险）。
4. **执行**：`POST /velocity` 失败频率；顶障时位姿是否冻结、`Failed to make progress`。
5. **不要用腿程低估碰撞**：leg odom 小步长会掩盖接触；优先看 RGB / reloc / 地图贴边。

## 3. 防御层次

| 层 | 要点 |
|----|------|
| 感知 | 连续高度带 / 有界 ray-march；减少 scan 缝隙；修深度视场与时间戳 |
| 地图 | unknown 保守处理；合理 footprint 与 inflation |
| 决策 | unknown 不可当整段可通行；限制 step、筛选前沿 |
| 控制 | 局部代价图覆盖；速度上限、制动距离；失锁停步 |
| 运行 | 急停、人工监护、安全超时停车 |

## 4. 安全操作

- 运动控制、覆盖探索前确认场地无人靠近与可退出区域。
- 改防撞参数后必须实机短冒烟，再长跑。
- 回滚保留上一版 launch/二进制或 git tag。
- 每次复现只改一层，在受控速度与监护下进行。

## 5. 与建图质量的边界

开环地图「known 高」仍可能导致错误通行判断；见 `visual-slam-mapping`。
语义旁路只增 occupied，不写 free；见 `semantic-occupancy-fusion`。

## 6. 实机复盘记录模板

```text
host_role: <robot_host> | <perception_host>
time_window: ...
monitor: vx/goal/known ...
map_snap: ...
reloc_jump: yes/no + magnitude
velocity_fail: count/rate
scan_gap_suspect: height bands ...
unknown_as_free: yes/no
local_costmap_size: ...
hypothesis: ...
one_layer_change: ...
result: ...
```

## 7. 与相关 Skills

- 建图/known% 误导：`visual-slam-mapping`
- 语义只增 occupied：`semantic-occupancy-fusion`
- 远端证据收集：`remote-ssh-dev`
