---
name: ros2-robotics
description: >-
  ROS2 robotics on remote Linux boards via SSH (perception and robot hosts).
  Use when working with ROS2 nodes, launch files, TF, Nav2, SLAM, colcon
  workspaces, or field tests on remote machines.
---

# ROS2 机器人开发（远程）

ROS 栈运行在**远端 Linux**；本机通过 SSH 或 Remote-SSH 操作。
路径用 `<project_root>`；主机用 `<perception_host>` / `<robot_host>` / `<ptq_host>`。

## 工作空间（远端执行）

```bash
ssh <perception_host> 'source /opt/ros/humble/setup.bash && cd <project_root> && colcon build --symlink-install'
ssh <perception_host> 'source <project_root>/install/setup.bash && ros2 launch ...'
```

- 区分 overlay/underlay；`AMENT_PREFIX_PATH` 在**运行节点的那台机器**上检查。
- launch/yaml 中的地址、路径、网卡名为远端环境，勿套 Windows 路径；公开文档用占位符。

## 跨机架构（角色）

| 侧 | 角色占位符 | 注意 |
|----|------------|------|
| 感知/导航/建图 | `<perception_host>` | Humble、RGB-D、Nav2、RTAB |
| 执行层 | `<robot_host>` | HTTP 桥、DDS 绑指定网卡 |
| BPU 量化 | `<ptq_host>` | 容器隔离；产物在 `<ptq_workspace>` |
| 设备 IPC 等 | 板端专用 `<project_root>` | 与导航仓分开标注 |
| 开发机 | 本机 / 云主机 | 文档、汇报存档 |

跨机无 ROS 域时只用 HTTP/明确接口；DDS 问题在**各端分别**查 `CYCLONEDDS_URI`、`RMW_IMPLEMENTATION`。

## 常见检查清单

- [ ] TF 链、`frame_id`、话题 QoS
- [ ] `use_sim_time` 一致
- [ ] 进程在预期主机：`ssh <Host> 'ros2 node list'`
- [ ] 建图：lost%/loops/path-span，不只 known%（见 `visual-slam-mapping`）
- [ ] 探索/覆盖：scan 缝隙与 unknown 通行策略（见 `nav-safety-collision`）
- [ ] USB 相机带宽与回调（见 `camera-usb-rgbd`）

## 实机 / 探索

- 日志：`/tmp/`、`~/logs/`、`ros2 bag`；汇报标注主机角色与路径占位符。
- 长探索用远端 `tmux`；断连后 `tmux attach` 续查输出。
- 会话产物写入约定目录（如 `<maps_output>/<session>/`）。
- 运动控制前确认场地安全；撞物复盘对齐 reloc 跳变与 monitor 时间线。

## 排错

```bash
ssh <perception_host> 'ros2 topic list; ros2 topic hz /scan'
ssh <perception_host> 'ros2 run tf2_tools view_frames'
ssh <robot_host> 'pgrep -af bridge; curl -s localhost:<port>/health'
```

## 相关 Skills

| 主题 | Skill |
|------|-------|
| RTAB/开环建图 | `visual-slam-mapping` |
| 语义/玻璃旁路 | `semantic-occupancy-fusion` |
| S600 HBM/PTQ | `horizon-bpu-ptq` |
| 撞物/覆盖安全 | `nav-safety-collision` |
| USB/RGBD | `camera-usb-rgbd` |
| 设备 IPC | `device-ipc-protocol` |

## 汇报取材

见 `remote-ssh-dev` -> remote-materials.md；指标表含**主机角色**列。
