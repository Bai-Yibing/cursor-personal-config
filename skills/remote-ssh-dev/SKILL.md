---
name: remote-ssh-dev
description: >-
  Remote SSH / Remote-SSH software development on Linux hosts: where to run
  commands, build/test on the deployment machine, collect logs and materials.
  Use when working through SSH, Cursor Remote-SSH, debugging remote services,
  or gathering evidence for reports. Absorbs former general-software-dev.
---

# 远程 SSH 开发（主工作模式）

代码默认在**远端 Linux** 构建/运行/验证；本机 Windows 为 Cursor 与文档存档。  
主机只用角色占位符：`<perception_host>`、`<robot_host>`、`<ptq_host>`、`<Host>`。  
材料清单见 [remote-materials.md](remote-materials.md)。

## 1. 执行位置

- 集成终端 `cwd` 为 `/home/...`、`/root/...` → 已在远端，直接跑命令。
- `cwd` 为 Windows 盘符 → `ssh <Host> '...'`，或切 Remote-SSH。

## 2. 标准流程

1. 确认**执行主机角色**与 `<project_root>`。
2. 读调用链；需运行时证据 → 在**部署机**复现，不单靠本机推断。
3. 最小正确 diff；改完确认已同步到将运行的环境。
4. 构建/测试在远端：`ssh <Host> 'cd <project_root> && <cmd>'` 或 Remote-SSH 终端。
5. 验证在**同一台会跑服务的机器**上查进程、端口、日志、话题。
6. 长任务：`tmux new -As <name>`；断连后 `tmux attach`。

## 3. 常用命令

```bash
ssh <perception_host> 'pgrep -af explore; tail -30 /tmp/supervisor.log 2>/dev/null'
ssh <robot_host> 'ss -tlnp | grep <port>; curl -s localhost:<port>/health'
ssh <perception_host> 'source /opt/ros/humble/setup.bash && source <project_root>/install/setup.bash && ros2 node list'
```

## 4. 输出与汇报

- 报告：改了什么、**哪台机器/角色**验证、如何复现。
- 路径对照：本机 vs `<project_root>/...`（若两边都有）。
- 写日报/知识库：读 [remote-materials.md](remote-materials.md)；证据标注 `???? | ????? | ??`。

## 5. 调试与安全

- 代理/防火墙：HTTP 桥、DDS 需网络都通；跨机只 HTTP 时不依赖 ROS 域。
- 不在对话/公开配置中硬编码密码；密钥用 ssh config。
- 实机改动前：备份配置、记录改前参数；运动控制先确认环境安全。
- 回滚：上一版二进制或 git tag。

## 6. 个人 Cursor 配置

详见 `cursor-config-sync`（真源、install、反向同步、bundle）。不要只改项目 `.cursor` 就结束。

## 7. 相关

| 主题 | Skill |
|------|-------|
| 配置同步 | `cursor-config-sync` |
| ROS2 | `ros2-robotics` |
| 建图/语义/NPU/防撞/相机/IPC | 对应领域 skills |
| 现场验证 | `field-validation-method` |
