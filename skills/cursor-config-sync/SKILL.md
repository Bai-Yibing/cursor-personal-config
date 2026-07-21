---
name: cursor-config-sync
description: >-
  Install and bidirectionally sync personal Cursor skills/rules via
  cursor-personal-config (GitHub). Use when opening SSH workspaces, installing
  config into a project, reverse-syncing project .cursor copies, bridging board
  commits with git bundle when push credentials are missing, or aligning
  Windows/Linux installs after config updates. Replaces former
  sync-cursor-to-project and cursor-config-remote-sync.
---

# Cursor 配置同步（安装 + 正/反向 + bundle 桥接）

**真源**：GitHub `cursor-personal-config`  
**机器克隆**：Linux `~/.cursor-personal-config`；Windows `$env:USERPROFILE\.cursor\cursor-personal-config`  
**项目副本**：`<project_root>/.cursor/rules|skills`（install 产物，**不是** git 真源）

## 1. 三层模型

| 层 | 角色 |
|----|------|
| Git 真源 | 唯一可公开发布的历史 |
| 机器克隆 | commit / push / pull 的工作副本 |
| 项目安装副本 | Agent 实际读到的文件 |

典型失败：只改项目副本就当已发布；板端无凭据推不上；两端各 ahead 互相覆盖。

## 2. 决策树

```text
要改个人 skills/rules？
  ├─ 能直改机器克隆？ → 是：路径 A（推荐） / 否：路径 B（先反向拷回）
  ├─ 当前机能 git push GitHub？ → 是：commit+push+install / 否：路径 C（bundle 桥接）
  └─ push 成功后 → 各机 pull + install-to-project
```

## 3. 路径 A — 直改克隆（推荐）

```bash
cd ~/.cursor-personal-config
git pull --rebase
# 编辑 rules/ skills/ sync-manifest.json（增删必改）
# 隐私/方法论自检（author-cursor-config）
git add -A && git commit -m "..." && git push origin main
~/.cursor-personal-config/scripts/install-to-project.sh <project_root>
```

Windows（`USERPROFILE\.cursor\rules|skills` 编辑层）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\publish-cursor-config.ps1"
cd $env:USERPROFILE\.cursor\cursor-personal-config
git push
```

## 4. 路径 B — 项目副本 → 克隆

```bash
git -C ~/.cursor-personal-config pull --rebase
PROJ="<project_root>"
cp -f "$PROJ/.cursor/rules/<name>.mdc" ~/.cursor-personal-config/rules/
cp -a "$PROJ/.cursor/skills/<skill>" ~/.cursor-personal-config/skills/
# 增删时改 sync-manifest.json
```

然后走 A 或 C。**禁止**拷进公开仓：`vln-*`、`project-overview`、工作存档/日报正文、真 IP/私有绝对路径。

## 5. 路径 C — 板端无 GitHub 凭据（bundle）

```bash
# 板端
cd ~/.cursor-personal-config
git status -sb   # ahead N，工作区干净
git fetch origin 2>/dev/null || true
git bundle create /tmp/cursor-personal-config.bundle origin/main..HEAD
git bundle verify /tmp/cursor-personal-config.bundle
```

```powershell
# 本机（有登录态）
cd $env:USERPROFILE\.cursor\cursor-personal-config
git pull origin main
git fetch $env:USERPROFILE\.cursor\cursor-personal-config.bundle HEAD:board-update
git merge board-update -m "Merge remote cursor-config updates"
git push origin main
git branch -d board-update
Remove-Item -Force $env:USERPROFILE\.cursor\cursor-personal-config.bundle -ErrorAction SilentlyContinue
```

```bash
# 板端对齐
git -C ~/.cursor-personal-config fetch origin
git -C ~/.cursor-personal-config merge --ff-only origin/main
~/.cursor-personal-config/scripts/install-to-project.sh <project_root>
```

不要把 bundle 提交进代码仓；不要 force push main。

## 6. 新机 / 新项目安装

```bash
# 每台 Linux 一次
git clone <cursor-personal-config-repo-url> ~/.cursor-personal-config
# 每个项目一次
~/.cursor-personal-config/scripts/install-to-project.sh <project_root>
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\cursor-personal-config\scripts\install-to-project.ps1" -ProjectRoot "D:\your\project"
```

## 7. 硬规则

- **只覆盖** `sync-manifest.json` 列出的同名文件
- **不删除** 项目自有 rules/skills
- **禁止** `rules/global/` 子目录
- Remote-SSH Agent **读不到** Windows `USERPROFILE\.cursor\`；勿从 user rules 自造
- 先 `pull` 再 `push`；密码/PAT 不写进 skills

## 8. 门禁与故障

| 检查 | 通过 |
|------|------|
| HEAD | 各机 == `origin/main` |
| 范围 | `git show --stat` 仅 manifest 个人文件 |
| 隐私 | 无 IP/密码/PAT/个人用户目录 |
| 安装 | 项目 `.cursor` 出现新内容 |
| 桥接 | bundle/临时分支已清 |

| 症状 | 处理 |
|------|------|
| push 要 Username | 走路径 C |
| bundle verify 失败 | 本机先 pull 到同基线 |
| merge 冲突 | 按方法论/隐私手工合 |
| 项目专有 rule 消失 | 只拷 manifest；从项目 git 恢复 |

## 9. 相关

- 撰写：`author-cursor-config`
- 隐私：`privacy-github`
- 远端开发：`remote-ssh-dev`
