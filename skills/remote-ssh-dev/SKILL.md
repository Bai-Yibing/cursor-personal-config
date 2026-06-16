---
name: remote-ssh-dev
description: >-
  Primary remote SSH development workflow on Linux servers (S100, Go2-SSH,
  cloud hosts). Use when executing commands, collecting logs, deploying code,
  debugging over SSH, Cursor Remote-SSH workspaces, or gathering materials
  for daily reports and knowledge base from remote machines.
---

# 远程 SSH 开发（主工作模式）

用户日常工作在**远程 Linux** 上完成；本机 Windows 负责 Cursor 与文档存档。

## 快速判定

- 集成终端 `cwd` 为 `/home/...`、`/root/...` → 已在远端，直接跑命令。
- `cwd` 为 `D:\...`、`C:\...` → 用 `ssh <Host> '...'` 操作远端，或提示用户切换 Remote-SSH。

主机列表见 [remote-materials.md](remote-materials.md)。

## 标准流程

1. **确认目标主机**（S100 / Go2-SSH / 云服务器等）与仓库路径。
2. **改代码**：Remote-SSH 工作区直接改；或本机改后 `git push` + 远端 `git pull`。
3. **远端构建/运行**：`source` ROS/venv → `colcon build` / `python3` / launch。
4. **验证**：在**同一台会跑服务的机器**上查进程、端口、日志、话题。
5. **长任务**：`tmux new -As <name>`，断连可 `tmux attach -t <name>`。

## 常用命令

```bash
# 远端一次性检查
ssh S100 'pgrep -af explore; tail -30 /tmp/supervisor.log 2>/dev/null'

# 健康与网络
ssh Go2-SSH 'ss -tlnp | grep 8765; curl -s localhost:8765/health'

# 带环境执行
ssh S100 'source /opt/ros/humble/setup.bash && source ~/ros_ws/install/setup.bash && ros2 node list'
```

## 写汇报/知识库时

必须读取 [remote-materials.md](remote-materials.md) 的「本地 + 远程」搜集清单；远程证据标注 `主机 | 路径 | 时间`。

## 调试要点

- 代理/防火墙：HTTP 桥、DDS 需本机与远端网络都通；跨机只 HTTP 时不依赖 ROS 域。
- 不在对话中硬编码密码；密钥用 ssh config。
- 生产/实机改动前：备份配置、记录改前参数值。

## 安全

- 运动控制、急停类操作先确认环境无人靠近。
- 回滚：保留上一版二进制或 git tag。
