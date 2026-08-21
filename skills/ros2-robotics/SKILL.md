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

- 区分 overlay/underlay；`AMENT_PREFIX_PATH` 在**运行节点的那台机器**上检查。并列实验仓必须各自清 prefix 再 source；发现路径含兄弟仓名应失败，禁止叠两套消息包/Cyclone XML。
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

### 多网卡 DDS 门禁

跨机话题“能发现但收不到数据”时，先把问题拆成发布端、发现和数据面，不要直接改 QoS 或业务节点：

1. 在两端记录 `ip -brief address`、路由和目标链路的邻居状态；多地址同网卡也算多网卡风险。
2. 用 `ros2 topic info -v <topic>` 确认发布端、类型和 QoS；发现成功只证明元数据可达。
3. 在订阅端显式绑定部署链路。多网卡先避开默认路由/无线；**同卡多个 IPv4** 时只绑与对端同网段的地址（Cyclone `NetworkInterface address=`），不要只绑网卡名——否则 SPDP 发现通、单播数据面 Hz=0。
4. 不要同时填接口 `name=` 和 `address=`：实现可能报二者不是同一接口，节点起不来。
5. 绑定前后只改网络接口这一项，并记录消息数或 Hz；无 A/B 证据不得宣称是 QoS 根因。

公开配置只写网卡角色或占位符，不写真实地址。

### 板端时钟与 RTC

跨机 stamp 差数分钟或数天时，先对齐墙上时钟，再谈每帧 rebase。嵌入式默认 `hwclock`/`rtc0` 可能是不走时的虚拟 RTC；要以 `timedatectl` 的 RTC 年份为准，必要时写真正走时的 rtc 设备。对端无公网时不要开会漂的 timesyncd；权威钟放在已 NTP 的主机，凭据不进仓库。阈值式 stamp 偏移只能会话内锁一次，禁止每帧 `stamp=now()`。

### 点云进入里程计前的坐标契约

- 先采样 `frame_id`、字段、点数、时间戳和点云语义，再选择 ICP/里程计输入。
- 只允许传感器或机体坐标云进入扫描匹配；已经表达在 `odom`/`map` 的世界坐标云只用于显示或对照，禁止再次估计运动。
- 紧耦合 LIO：话题与 KF 开关以**厂商同传感器 launch/yaml** 为准，不要用包内 C++ 默认。雷达系原始云与已变到 `base_link` 的云不要混订。
- `slam_toolbox` 在跑时禁止再发恒等 `map→odom`；恒等静态 TF 只给「无图、局部滚动 costmap」模式。全局 `/map` 与滚动 local costmap 不要混成同一验收。
- 适配节点至少硬门禁允许 frame、`x/y/z` 字段、最小点数和字节布局；新固件或新 topic 必须重采契约。
- 跨机时间戳偏差应先修系统同步。阈值式重基只能默认关闭、显式启用并记录原偏差，且只能作为同步修复前的短冒烟保护。
- 若必须重基：只锁定一次常数偏移，用 `source + offset` 保留帧间 dt。禁止每帧把 stamp 改成 `now()`；那会把传感器真实频率伪装成更高更新率，下游里程计按 `expected_update_rate` 丢帧。

## 常见检查清单

- [ ] TF 链、`frame_id`、话题 QoS
- [ ] `use_sim_time` 一致
- [ ] 进程在预期主机：`ssh <Host> 'ros2 node list'`；同机禁止第二套相机/建图 launch
- [ ] 建图：lost%/loops、节点 AABB、占用/已知比，不只 known% 或 `mapped_with_loop`（见 `visual-slam-mapping`）
- [ ] 两套扫描匹配/2D SLAM 不要订同一 `/scan`；积帧激光用专用话题
- [ ] 实时点云多为 BEST_EFFORT：下游默认 RELIABLE 会零订阅；对点云用 SensorDataQoS 再查 Hz
- [ ] 探索/覆盖：scan 缝隙与 unknown 通行策略（见 `nav-safety-collision`）
- [ ] USB 相机带宽与回调（见 `camera-usb-rgbd`）

## 实机 / 探索

- 日志：`/tmp/`、`~/logs/`、`ros2 bag`；汇报标注主机角色与路径占位符。
- 长探索用远端 `tmux`；断连后 `tmux attach` 续查输出。
- 会话产物写入约定目录（如 `<maps_output>/<session>/`）。
- 运动控制前确认场地安全；撞物复盘对齐 reloc 跳变与 monitor 时间线。
- 四足低速不走：先查步态是否仍是默认小跑（低于门槛会原地抖），不要先把导航上限加大来“骗过”步态。演示碎步往往是行走步态 + 持续速度指令，不是更大 `max_vel_x`。

## 排错

```bash
ssh <perception_host> 'ros2 topic list; ros2 topic hz /scan'
ssh <perception_host> 'ros2 run tf2_tools view_frames'
ssh <robot_host> 'pgrep -af bridge; curl -s localhost:<port>/health'
```

## 相关 Skills

| 主题 | Skill |
|------|-------|
| 建图方法论 | `visual-slam-mapping` |
| 语义占据融合 | `semantic-occupancy-fusion` |
| 边缘 NPU/PTQ | `horizon-bpu-ptq` |
| 防撞与安全 | `nav-safety-collision` |
| USB/RGBD 诊断 | `camera-usb-rgbd` |
| 设备 IPC | `device-ipc-protocol` |
| 现场验证方法 | `field-validation-method` |

## 汇报取材

见 `remote-ssh-dev` -> remote-materials.md；指标表含**主机角色**列。
