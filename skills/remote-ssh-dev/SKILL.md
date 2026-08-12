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
7. **长编译/量化**：一任务一容器（或一 GPU）；并行任务换容器换卡，避免互相 OOM/拖死。

### 2.1 报告前主机清单门禁

写日报、经验总结或现场汇报前，不能把当前 Remote-SSH 会话视为全部环境。先建立当天候选主机清单，来源至少包括：本机 SSH config 的别名、已知角色主机（`<perception_host>` / `<robot_host>` / `<ptq_host>` / `<Host>`）、当天出现过的终端/Agent 记录，以及用户明确提到的可连接目标。

对清单中的每个候选主机逐台执行只读探测，并记录：

- 主机角色与脱敏别名；连接状态、探测时间和失败原因；
- 当天涉及的项目根、`git status`、当天 `git log`/`git diff`；
- 进程/服务、tmux 会话、关键日志和结构化评测结果；
- 结论是“有当日证据”“已连接但无当日活动”“无法连接/权限不足”还是“待用户确认”。

连接失败或没有当日活动的主机也必须进入取材台账，不能静默省略。只有完成逐主机台账，才可开始写“今日全部工作”或“已完成全面取材”；若清单来源不完整，报告标题或正文须标记“主机覆盖不完整”。

## 3. 常用命令

```bash
ssh <perception_host> 'pgrep -af explore; tail -30 /tmp/supervisor.log 2>/dev/null'
ssh <robot_host> 'ss -tlnp | grep <port>; curl -s localhost:<port>/health'
ssh <perception_host> 'source /opt/ros/humble/setup.bash && source <project_root>/install/setup.bash && ros2 node list'
```

## 4. 输出与汇报

- 报告：改了什么、**哪台机器/角色**验证、如何复现。
- 路径对照：本机 vs `<project_root>/...`（若两边都有）。
- 写日报/知识库：读 [remote-materials.md](remote-materials.md)；证据标注 `主机角色 | 路径占位符 | 时间`。

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
