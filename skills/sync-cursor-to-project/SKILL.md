---
name: sync-cursor-to-project
description: >-
  Install personal Cursor rules/skills from git repo cursor-personal-config into
  any project, and reverse-sync Remote-SSH project copies back to the git source
  before push. Not bound to a specific SSH host. Use when opening SSH workspace,
  new project, syncing cursor config, or pushing skills/rules edited under
  project .cursor to GitHub.
disable-model-invocation: true
---

# 同步 Rules/Skills（Git 方案，不绑定 SSH 主机）

**真源**：Git 仓库 `cursor-personal-config`（推 GitHub）  
**Linux 克隆**：`~/.cursor-personal-config`  
**本机克隆**：`$env:USERPROFILE\.cursor\cursor-personal-config`  
**目标**：项目 `.cursor/rules/`、`.cursor/skills/`（扁平，与项目 rules 同级）

## 正向：仓 → 项目

```text
编辑真源 rules|skills
  →（Windows）publish-cursor-config.ps1 → git push
  →（Linux）在 ~/.cursor-personal-config 直接 commit + push
  → 每台 Linux: git clone 一次到 ~/.cursor-personal-config
  → 每个项目: install-to-project.sh <项目路径>
  → 之后 sessionStart hook 可自动 git pull + 合并
```

## 反向：项目副本 → 仓（Remote-SSH 常见）

在 Remote-SSH 工作区改的是**项目副本**，推 GitHub 前必须写回真源：

```bash
# 1. 确认仓存在；没有则 clone
ls ~/.cursor-personal-config || git clone <repo_url> ~/.cursor-personal-config

# 2. 先拉最新
git -C ~/.cursor-personal-config pull --rebase

# 3. 只拷 sync-manifest.json 列出的个人文件（示例）
PROJ="<project_root>"
cp -f "$PROJ/.cursor/rules/<rule>.mdc" ~/.cursor-personal-config/rules/
cp -a "$PROJ/.cursor/skills/<skill>" ~/.cursor-personal-config/skills/
# 增删条目时改：~/.cursor-personal-config/sync-manifest.json

# 4. 隐私自检后提交推送
cd ~/.cursor-personal-config
git add -A && git status
git commit -m "Update skills/rules from remote workspace"
git push
```

**禁止**拷进公开仓：项目专有 `vln-*`、`project-overview`、工作存档/日报正文、真实 IP/绝对私有路径。

## 更省事的习惯

以后在 SSH 工作区改个人配置时，**直接改** `~/.cursor-personal-config/rules|skills`，再：

```bash
git -C ~/.cursor-personal-config add -A
git -C ~/.cursor-personal-config commit -m "..."
git -C ~/.cursor-personal-config push
~/.cursor-personal-config/scripts/install-to-project.sh "$(pwd)"
```

## 新 SSH 主机（每台一次）

```bash
git clone https://github.com/Bai-Yibing/cursor-personal-config.git ~/.cursor-personal-config
```

## 新 / 任意 SSH 工作区（每个仓库一次）

```bash
~/.cursor-personal-config/scripts/install-to-project.sh "$(pwd)"
```

## 本机 Windows 项目

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\cursor-personal-config\scripts\install-to-project.ps1" -ProjectRoot "D:\your\project"
```

## 本机发布修改

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\publish-cursor-config.ps1"
cd $env:USERPROFILE\.cursor\cursor-personal-config
git push
```

## 规则

- **只覆盖** `sync-manifest.json` 列出的同名文件
- **不删除** 项目自有：`project-overview`、`ros2-cpp`、`vln-*` 等
- **禁止** `rules/global/` 子目录
- Remote-SSH Agent **读不到** `$env:USERPROFILE\.cursor\`，勿从 user rules 臆造
- 本机与远端都有未推改动时：先两边 `git pull` 再合并，避免互相覆盖

## 远端 Agent

若 `~/.cursor-personal-config` 不存在，提示用户先 `git clone`；然后运行 `install-to-project.sh`。
