---
name: remote-ssh-dev
description: >-
  Primary remote SSH development workflow on Linux servers (perception, robot,
  PTQ hosts). Use when executing commands, collecting logs, deploying code,
  debugging over SSH, Cursor Remote-SSH workspaces, or gathering materials
  for daily reports and knowledge base from remote machines.
---

# 远程 SSH 开发（主工作模式）

用户日常工作在**远程 Linux** 上完成；本机 Windows 负责 Cursor 与文档存档。
主机只用角色占位符：`<perception_host>`、`<robot_host>`、`<ptq_host>`、`<Host>`。
详细收集清单见 [remote-materials.md](remote-materials.md)。

## 快速判定

- 集成终端 `cwd` 为 `/home/...`、`/root/...` -> 已在远端，直接跑命令。
- `cwd` 为 Windows 盘符路径 -> 用 `ssh <Host> '...'` 操作远端，或切换 Remote-SSH。

## 标准流程

1. **确认目标主机角色**与 `<project_root>`。
2. **改代码**：Remote-SSH 工作区直接改；或本机改后 `git push` + 远端 `git pull`。
3. **远端构建/运行**：`source` ROS/venv -> `colcon build` / `python3` / launch。
4. **验证**：在**同一台会跑服务的机器**上查进程、端口、日志、话题。
5. **长任务**：`tmux new -As <name>`，断连可 `tmux attach -t <name>`。

## 常用命令（角色化）

```bash
ssh <perception_host> 'pgrep -af explore; tail -30 /tmp/supervisor.log 2>/dev/null'
ssh <robot_host> 'ss -tlnp | grep <port>; curl -s localhost:<port>/health'
ssh <perception_host> 'source /opt/ros/humble/setup.bash && source <project_root>/install/setup.bash && ros2 node list'
```

## 写汇报 / 知识库时

必须读取 [remote-materials.md](remote-materials.md)；远程证据标注 `主机角色 | 路径占位符 | 时间`。

## 调试要点

- 代理/防火墙：HTTP 桥、DDS 需本机与远端网络都通；跨机只 HTTP 时不依赖 ROS 域。
- 不在对话中硬编码密码；密钥用 ssh config。
- 生产/实机改动前：备份配置、记录改前参数值。
- 公开文档禁止 IP、串号、真实绝对私有路径。

## 安全

- 运动控制、急停类操作先确认环境无人靠近。
- 回滚：保留上一版二进制或 git tag。

## 与其它 Skills

| 主题 | Skill |
|------|-------|
| ROS2 / 实机 | `ros2-robotics` |
| 建图 | `visual-slam-mapping` |
| BPU/PTQ | `horizon-bpu-ptq` |
| 防撞 | `nav-safety-collision` |
| USB 相机 | `camera-usb-rgbd` |
| 设备 IPC | `device-ipc-protocol` |

## 禁止写入公开配置的内容

- 真实 IP、密码、token、串号、RTSP 凭据
- 固定私有绝对路径（改用 `<project_root>` / `$env:USERPROFILE`）
- 可识别个人/公司内网拓扑的主机名以外的敏感信息
