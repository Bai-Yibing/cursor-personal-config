---
name: nav-safety-collision
description: >-
  Robot navigation collision diagnosis and layered safety (depth-to-scan gaps,
  coverage treating unknown as free, Nav2 costmap, reloc jumps). Use when Go2
  hits obstacles, explore/coverage stuck, velocity POST failures, or reviewing
  field-test collision logs.
---

# 导航防撞与撞物排查

实机撞物多为系统性缝隙，很少是单一「Nav2 配错」。

## 1. 典型根因组合

```text
depth -> scan height bands have gaps  -->  thin obstacles miss /scan
coverage/explore treats unknown as free -->  long steps into unmapped frontier
Nav2 local costmap too small, no static -->  relies only on live /scan
large visual reloc jump               -->  strong proxy for collision / e-stop
```

## 2. 排查顺序（远端证据）

1. 时间对齐：撞点前后的 monitor（vx、goal、known）、map 快照、tracking_events / reloc jump、用户目视。
2. 感知：`depth_to_scan` 高度带是否连续；带间是否漏桌腿/墙缘。
3. 决策：coverage 是否允许 unknown 通行；`step_m` 是否过大（>= 1.5m 高风险）。
4. 执行：`POST /velocity failed` 频率；顶障时位姿是否冻结、`Failed to make progress`。
5. 不要用腿程低估碰撞：leg odom 小步长会掩盖接触；优先看 RGB / reloc / 地图贴边。

## 3. 防御层次

| 层 | 要点 |
|----|------|
| 感知 | 连续高度带 / 有界 ray-march；减少 scan 缝隙 |
| 决策 | unknown 不可当整段可通行；限制 step、筛选前沿 |
| 控制 | 局部代价图覆盖；必要时降速/停；失锁停步 |
| 工程 | 录像与 dashboard 依赖勿被同名 import 覆盖（如 `Path`） |

## 4. 安全操作

- 运动控制、覆盖探索前确认场地无人靠近。
- 改防撞参数后必须实机短冒烟，再长跑。
- 回滚保留上一版 launch/二进制或 git tag。

与建图质量问题区分：开环地图「known 高」仍可能导致错误通行判断；见 `visual-slam-mapping`。
