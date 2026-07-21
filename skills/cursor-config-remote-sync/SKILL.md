---
name: cursor-config-remote-sync
description: >-
  Bidirectional sync of personal Cursor skills/rules across Windows, Remote-SSH
  Linux boards, and GitHub cursor-personal-config. Use when editing skills/rules
  on a remote host, reverse-syncing project .cursor copies, bridging commits with
  git bundle when the board cannot push, or aligning local/global/project installs
  after a config update.
---

# Cursor 配置远端同步方法论

解决：在 Remote-SSH / 板端改了 skills/rules 后，如何安全、可复现地写回真源并推到 GitHub，再让本机与其它机器对齐。

## 1. 问题定义

个人 Cursor 配置存在三层：

| 层 | 位置 | 角色 |
|----|------|------|
| **Git 真源** | GitHub `cursor-personal-config` | 唯一可公开发布的历史 |
| **机器克隆** | Linux `~/.cursor-personal-config`；Windows `$env:USERPROFILE\.cursor\cursor-personal-config` | 推送/拉取的工作副本 |
| **项目安装副本** | `<project_root>/.cursor/rules|skills` | Agent 实际读到的文件；**不是** git 真源 |

典型失败：只改项目副本就当已发布；板端 HTTPS 无凭据推不上；本机与板端各 ahead 互相覆盖。

## 2. 不变量 / 第一性原理

1. **真源唯一**：只有 git 仓库（及其各机克隆）承担发布历史；项目 `.cursor` 是 install 产物。
2. **凭据分离**：板端可无 GitHub 登录；推送可在「有登录态的机器」完成（通常为本机 Windows）。
3. **不写密码进仓库**：SSH 密码/PAT 仅存于本机密钥链/凭据管理器；skills 只写角色与流程。
4. **manifest 门禁**：只同步 `sync-manifest.json` 列出的个人文件；不携项目专有 rules。
5. **先拉后推**：任何一端 commit 前先 `fetch/pull`，避免分叉盲推。

## 3. 决策树（先选路径）

```text
要改个人 skills/rules？
  │
  ├─ 能直接编辑机器克隆？
  │     ├─ 是 → 路径 A：直改 ~/.cursor-personal-config（推荐）
  │     └─ 否（只改了项目 .cursor） → 路径 B：先反向拷回克隆
  │
  ├─ 当前机能 git push GitHub？
  │     ├─ 是 → commit + push，再 install 到项目
  │     └─ 否 → 路径 C：bundle/补丁 → 有凭据机器 merge + push
  │
  └─ push 成功后 → 各机 pull + install-to-project
```

## 4. 路径 A — 推荐 SOP（直改克隆）

```bash
cd ~/.cursor-personal-config   # 或 Windows 下对应克隆目录
git pull --rebase
# 编辑 rules/ skills/ sync-manifest.json README
# 隐私与方法论自检（见 author-cursor-config）
git add -A && git status
git commit -m "Describe why the playbook changed"
git push origin main
~/.cursor-personal-config/scripts/install-to-project.sh <project_root>
```

Windows 若真源在 `$env:USERPROFILE\.cursor\rules|skills`：先 `publish-cursor-config.ps1` 再 `git push`。

## 5. 路径 B — 项目副本 → 克隆

```bash
git -C ~/.cursor-personal-config pull --rebase
PROJ="<project_root>"
# 仅拷 manifest 中的个人文件
cp -f "$PROJ/.cursor/rules/<name>.mdc" ~/.cursor-personal-config/rules/
cp -a "$PROJ/.cursor/skills/<skill>" ~/.cursor-personal-config/skills/
# 增删时同步改 sync-manifest.json
```

然后走路径 A 的 commit/push，或若不能 push 则走路径 C。

## 6. 路径 C — 板端无 GitHub 凭据（bridge）

适用：板端已 `commit` 且 `ahead of origin`，但 `git push` 报 `could not read Username` / 无 SSH key。

### C1. 在板端打 bundle

```bash
cd ~/.cursor-personal-config
git status -sb          # 应为 ahead N，工作区干净
git fetch origin 2>/dev/null || true
git bundle create /tmp/cursor-personal-config.bundle origin/main..HEAD
git bundle verify /tmp/cursor-personal-config.bundle
```

### C2. 传到有 GitHub 登录态的机器（通常本机）

```text
scp / 图形化下载 / SFTP / Agent 代拉
→ 本机临时路径（例如 $env:USERPROFILE\.cursor\cursor-personal-config.bundle）
```

不要把 bundle 提交进任何代码仓库。

### C3. 本机合并并 push

```powershell
cd $env:USERPROFILE\.cursor\cursor-personal-config
git pull origin main
git fetch .\cursor-personal-config.bundle HEAD:board-update
# 若 bundle 不在仓库目录，用绝对路径：
# git fetch $env:USERPROFILE\.cursor\cursor-personal-config.bundle HEAD:board-update
git log --oneline origin/main..board-update
git merge board-update -m "Merge remote cursor-config updates"
git push origin main
git branch -d board-update
Remove-Item -Force $env:USERPROFILE\.cursor\cursor-personal-config.bundle -ErrorAction SilentlyContinue
```

### C4. 各端对齐

```bash
# 板端
git -C ~/.cursor-personal-config fetch origin
git -C ~/.cursor-personal-config merge --ff-only origin/main
~/.cursor-personal-config/scripts/install-to-project.sh <project_root>

# 本机（若还有 USERPROFILE\.cursor 真源编辑层）
# 从克隆按 manifest 覆盖到 USERPROFILE\.cursor\rules|skills
# 并 install-to-project.ps1 到本地项目
```

## 7. 度量与门禁

| 检查 | 通过标准 |
|------|----------|
| 真源一致 | 各机 `git rev-parse HEAD` == `origin/main` |
| 发布范围 | `git show --stat` 仅含 manifest 内个人文件 |
| 隐私 | 无 IP/密码/PAT/个人用户目录 |
| 项目安装 | install 后项目 `.cursor` 出现新 skill/rule |
| 桥接完成 | bundle 已删除；`board-update` 分支已删 |

## 8. 故障分类学

| 症状 | 可能原因 | 否证/处理 |
|------|----------|------------|
| push 要 Username | 板端无 GitHub 凭据 | 走路径 C；或配 SSH remote |
| bundle verify 失败 | 基线不在本机历史 | 本机先 `git pull` 到同基线 |
| merge 冲突 | 两端改同文件 | 按方法论/隐私规则手工合；不要盲目 theirs |
| install 后看不到更新 | 未改 manifest 或装错项目根 | 检查 manifest 与 `<project_root>` |
| 项目专有 rule 消失 | 错把整个 `.cursor` 覆盖真源 | 只拷 manifest 列表；从 git 恢复项目文件 |

## 9. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 认为改项目 `.cursor` 就算发布 | 其它机/仓库无历史 | 必须进 git 真源再 push |
| 把板端密码写进 skill | 公开仓泄密 | 仅用 `<Host>`；密钥/凭据管理器 |
| 在无凭据机上死推 | 阻塞工作流 | bundle 桥接到有登录态机 |
| force push 解冲突 | 丢历史 | rebase/merge；禁止 force main |
| 忘记各端 install | Agent 仍读旧副本 | push 后 pull + install |

## 10. 交付清单

- [ ] 已选路径 A/B/C 之一并记录
- [ ] `origin/main` 含本次变更；各机 HEAD 对齐
- [ ] manifest/隐私/方法论自检通过
- [ ] 相关项目已 install
- [ ] 临时 bundle/分支已清理

## 11. 相关

- 安装与正向同步：`sync-cursor-to-project`
- 撰写规范：`author-cursor-config`
- 隐私：`privacy-github`
- 远端执行：`remote-ssh-dev`
