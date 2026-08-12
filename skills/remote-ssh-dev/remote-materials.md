# 远程 SSH 环境 -- 材料收集与执行参考

汇报、知识库、排错时共用本文。配套 skill：`remote-ssh-dev`。

## 双环境分工

| 位置 | 用途 | 路径约定 |
|------|------|----------|
| **本机 Windows** | Cursor、对话记录、汇报/知识库终稿 | `$env:USERPROFILE\Documents\` 或团队约定目录 |
| **远程 Linux** | 代码、编译、实机、日志、汇报暂存 | `<project_root>/.cursor/工作存档/`（再 pull 到本机） |

## 角色主机表（禁止写真实 IP）

| 角色占位符 | 常见用途 |
|------------|----------|
| `<perception_host>` | 感知/导航/SLAM、相机、语义节点 |
| `<robot_host>` | 执行层、HTTP 桥、实机运动 |
| `<ptq_host>` | Horizon PTQ / HBM 编译（容器） |
| `<Host>` | 通用 SSH 目标 |

当日涉及哪台角色主机，材料收集和汇报正文都要**点名标注**。BPU 任务另记**容器名与 GPU 编号**（不写内网 IP）。

## 本地材料（Windows）

1. **对话**：`$env:USERPROFILE\.cursor\projects\*\agent-transcripts\*.jsonl`
2. **终端**：`$env:USERPROFILE\.cursor\projects\*\terminals\*.txt`
3. **已有汇报终稿**：本机文档目录（按团队约定）
4. **远端汇报暂存**：`<project_root>/.cursor/工作存档/` -> 本机 pull 脚本拉回

## 远程材料（先盘点主机，再逐台执行）

### 主机覆盖台账

日报/经验取材先写一份临时台账（可放在当天归档草稿中，不进入个人配置仓）：

```text
host_role | alias | source | probe_time | connection | projects | evidence | conclusion
<ptq_host> | <Host> | ssh-config + terminal | YYYY-MM-DD HH:MM | connected | <project_root> | git/log/report | evidence_found
<robot_host> | <Host> | known-role | YYYY-MM-DD HH:MM | failed | unknown | none | connection_failed
```

候选主机来源包括 SSH config 别名、已知角色、当天终端/Remote-SSH 记录和用户明确提供的目标。失败、无活动、权限不足和待确认都要保留在台账中。台账未完成时，不得把报告写成“今日全部工作”。

### 按主机角色执行

```bash
git log --since="today 0:00" --oneline
git diff
git status
pgrep -af '<keyword>' || true
ss -tlnp | grep '<port>' || true
tail -n 200 /tmp/*.log 2>/dev/null
source /opt/ros/*/setup.bash 2>/dev/null; source <project_root>/install/setup.bash 2>/dev/null
ros2 node list 2>/dev/null
tmux capture-pane -pt '<session>' -S -300 2>/dev/null
```

每台主机至少保存一条可追溯证据或失败原因，并标注 `主机角色 | 项目根 | 时间`。不要只收集当前终端所在主机。

## 执行方式

```bash
ssh <perception_host> 'cd <project_root> && git log -3 --oneline'
ssh -t <Host>
tmux new -As dev
```

## 汇报记录规范

```text
[remote] host=<perception_host> | path=<project_root>/... | time=YYYY-MM-DD HH:MM
evidence: git diff / tail log / ros2 topic hz ...
```

- 指标表增加「主机角色」列。
- 公开文档剥离 IP、账号、串号、私有绝对路径。

## 汇报存档（远端 -> 本机）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\pull-reports-to-local.ps1" -SshHost <Host> -RemoteStagingPath "<project_root>/.cursor/工作存档"
```

## 同步注意

- 代码以 git 或项目约定方式同步；汇报不写「已部署」除非远端 `git log`/文件时间可证。
- 改 launch/配置后注明是否已在远端 `source` 并重启节点。
