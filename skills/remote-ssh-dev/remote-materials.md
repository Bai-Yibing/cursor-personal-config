# 远程 SSH 环境 — 材料搜集与执行参考

汇报、知识库、排错时共用本文。

## 双环境分工

| 位置 | 用途 | 典型路径 |
|------|------|----------|
| **本机 Windows** | Cursor、对话记录、**汇报/知识库终稿（权威）** | `D:\Documents\` |
| **远程 Linux** | 代码、编译、实机、日志、**汇报暂存** | `/root/vln/.cursor/工作存档/`（pull 到本机） |

## 已配置 SSH 主机

（来自 `remote.SSH.remotePlatform`，别名以 Cursor/ssh config 为准）

| 别名 | 平台 | 常见用途 |
|------|------|----------|
| `S100` / `S100-SSH` | linux | 感知/导航/SLAM（`/root/vln`） |
| `Go2-SSH` | linux | 机器狗端侧执行、HTTP 桥 |
| `192.168.1.56` | linux | 内网开发机 |
| `47.116.133.221` | linux | 云服务器 |
| 内网 GPU 机（如 `192.168.2.128`） | linux | Horizon PTQ / HBM 编译（容器） |
| XC100 等板端 | linux | 人脸/IPC 等（仓库常在 `/root/fr`） |

当日涉及哪台主机，材料搜集和汇报正文都要**点名标注**。BPU 任务另记**容器名与 GPU 编号**。

## 本地材料（Windows）

1. **对话**：`C:\Users\19944\.cursor\projects\*\agent-transcripts\*.jsonl`
2. **终端**：`C:\Users\19944\.cursor\projects\*\terminals\*.txt`（含 `ssh` 会话里的命令与输出）
3. **已有汇报（本机终稿）**：`D:\Documents\工作汇报\`、`D:\Documents\知识库\`
4. **远端汇报暂存**（汇总前先 pull）：`/root/vln/.cursor/工作存档/` → 运行 `pull-reports-to-local.ps1`

## 远程材料（按主机执行）

对当日用过的每个 `Host`，在远端或通过 `ssh Host '...'` 收集：

```bash
# 代码变更（进入实际仓库目录）
git log --since="今天0点" --oneline
git diff
git status

# 进程与服务
pgrep -af '<关键词>' || true
ss -tlnp | grep '<端口>' || true

# 日志（按项目调整路径）
tail -n 200 /tmp/*.log 2>/dev/null
ls -lt ~/logs/ 2>/dev/null | head
journalctl --since today -u '<服务名>' --no-pager 2>/dev/null | tail -50

# ROS2（若在跑）
source /opt/ros/*/setup.bash 2>/dev/null; source install/setup.bash 2>/dev/null
ros2 node list 2>/dev/null
ros2 topic hz /scan 2>/dev/null

# tmux 历史（会话名按实际）
tmux capture-pane -pt '<session>' -S -300 2>/dev/null
```

## 执行方式选择

```bash
# 工作区在 Windows，单次远端命令
ssh S100 'cd /root/vln && git log -3 --oneline'

# 工作区已通过 Remote-SSH 打开远端目录 → 直接在终端执行，无需 ssh 前缀

# 需交互或长任务
ssh -t S100
tmux new -As dev
```

## 汇报/知识库中的记录规范

每条远程证据写清：

```text
[远程] 主机=S100 | 路径=/root/vln/s100_nav | 时间=2026-06-16 15:30
证据：git diff / tail 日志 / ros2 topic hz …
```

- 指标表增加「主机」列。
- 复现命令写**远端可执行**的完整形式（含 `ssh Host` 前缀若本机执行）。
- 本机与远端路径对照表（若两边都有副本）：

| 说明 | 本机 | 远端 |
|------|------|------|
| … | `D:\...` 或 未同步 | `/root/...` |

## 汇报存档（远端 → 本机）

在 Remote-SSH 工作区写完日报/周报/知识库后：

```powershell
# 本机执行，拉回 D:\Documents
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\pull-reports-to-local.ps1" -SshHost S100-SSH -RemoteStagingPath /root/vln/.cursor/工作存档
```

详见 `C:\Users\19944\.cursor\scripts\save-work-reports.md`。

## 同步注意

- 代码以 **git** 或项目约定方式同步；汇报不写「已部署」除非远端 `git log`/文件时间可证。
- 改 launch/配置后注明是否已在远端 `source` 并重启节点。
