---
name: sync-cursor-to-project
description: >-
  Install personal Cursor rules/skills from git repo cursor-personal-config into
  any project. Not bound to a specific SSH host. Use when opening SSH workspace,
  new project, or user asks to sync cursor config.
disable-model-invocation: true
---

# 同步 Rules/Skills（Git 方案，不绑定 SSH 主机）

**真源**：Git 仓库 `cursor-personal-config`（推 GitHub）  
**目标**：当前项目 `.cursor/rules/`、`.cursor/skills/`（扁平，与项目 rules 同级）

## 流程

```text
编辑 $env:USERPROFILE\.cursor\rules|skills
  → publish-cursor-config.ps1 → git push (GitHub)
  → 每台 Linux: git clone 一次到 ~/.cursor-personal-config
  → 每个项目: install-to-project.sh <项目路径>
  → 之后 sessionStart hook 自动 git pull + 合并
```

## 新 SSH 主机（每台一次）

```bash
git clone https://github.com/你的用户名/cursor-personal-config.git ~/.cursor-personal-config
```

## 新 / 任意 SSH 工作区（每个仓库一次）

```bash
~/.cursor-personal-config/scripts/install-to-project.sh "$(pwd)"
# 或指定路径：.../install-to-project.sh <project_root>
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

## 远端 Agent

若 `~/.cursor-personal-config` 不存在，提示用户先 `git clone`；然后运行 `install-to-project.sh`。

## 仓库路径

- 本机克隆：`$env:USERPROFILE\.cursor\cursor-personal-config`
- Linux：`~/.cursor-personal-config`
- 说明：`cursor-personal-config/README.md`
