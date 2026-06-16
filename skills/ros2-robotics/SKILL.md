---
name: ros2-robotics
description: >-
  ROS2 robotics on remote Linux boards via SSH (S100, Go2, edge devices).
  Use when working with ROS2 nodes, launch files, TF, Nav2, SLAM, colcon
  workspaces, or field tests on remote machines.
---

# ROS2 机器人开发（远程）

ROS 栈运行在**远端 Linux**（如 S100 Humble、Go2 Foxy）；本机通过 SSH 或 Remote-SSH 操作。

## 工作空间（远端执行）

```bash
# Remote-SSH 终端或：
ssh S100 'source /opt/ros/humble/setup.bash && cd ~/ros_ws && colcon build --symlink-install'
ssh S100 'source ~/ros_ws/install/setup.bash && ros2 launch ...'
```

- 区分 overlay/underlay；`AMENT_PREFIX_PATH` 在**运行节点的那台机器**上检查。
- launch/yaml 中的 IP、路径、网卡名为远端环境，勿套 Windows 路径。

## 跨机架构

| 侧 | 典型主机 | 注意 |
|----|----------|------|
| 感知/导航 | S100 | Humble、RealSense、Nav2 |
| 执行层 | Go2-SSH | Foxy、HTTP 桥、DDS 绑 eth0 |
| 开发机 | 本机 / 云服务器 | 文档、汇报存档 |

跨机无 ROS 域时只用 HTTP/明确接口；DDS 问题在**各端分别**查 `CYCLONEDDS_URI`、`RMW_IMPLEMENTATION`。

## 常见检查清单（均在对应远端执行）

- [ ] TF 链、`frame_id`、话题 QoS
- [ ] `use_sim_time` 一致
- [ ] 进程在预期主机：`ssh S100 'ros2 node list'`

## 实机 / 探索

- 日志：`/tmp/`、`~/logs/`、`ros2 bag`；汇报标注主机与路径。
- 长探索用远端 `tmux`；断连后 `tmux attach` 续查输出。
- 会话产物（map.pgm 等）路径写**远端绝对路径**。

## 排错（SSH 到出问题的那台）

```bash
ssh S100 'ros2 topic list; ros2 topic hz /scan'
ssh S100 'ros2 run tf2_tools view_frames'  # 或导出 tf 树
ssh Go2-SSH 'pgrep -af bridge; curl -s localhost:8765/health'
```

## 汇报取材

见 `remote-ssh-dev` → remote-materials.md；指标表含**主机**列。
