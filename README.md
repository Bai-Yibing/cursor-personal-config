# Cursor 个人配置（Rules + Skills）

**不绑定任何 SSH 主机或项目路径**。真源是此 Git 仓库；任意工作区按需 pull 安装。

## 架构

```text
本机编辑 C:\Users\19944\.cursor\rules|skills
        ↓ publish-cursor-config.ps1
cursor-personal-config（本仓库）→ git push → GitHub
        ↓ git pull
~/.cursor-personal-config（每台 Linux 主机克隆一次）
        ↓ install-to-project.sh
任意项目 /root/xxx/.cursor/（合并个人 rules/skills，保留项目自有配置）
```

## 一次性：推到 GitHub

1. 在 GitHub 新建**私有**仓库 `cursor-personal-config`（不要 README）
2. 编辑 `config.json` 里的 `repo_url`
3. 本机 PowerShell：

```powershell
cd $env:USERPROFILE\.cursor\cursor-personal-config
git remote add origin https://github.com/你的用户名/cursor-personal-config.git
git push -u origin main
```

## 本机：改完配置后发布

```powershell
# 1. 在 C:\Users\19944\.cursor\rules 或 skills 里改文件
# 2. 发布到 git 仓库并 commit
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\publish-cursor-config.ps1"
cd $env:USERPROFILE\.cursor\cursor-personal-config
git push
```

## 新 SSH 主机（每台做一次）

```bash
git clone https://github.com/你的用户名/cursor-personal-config.git ~/.cursor-personal-config
```

## 新 SSH 工作区 / 任意项目（每个仓库做一次）

```bash
~/.cursor-personal-config/scripts/install-to-project.sh /path/to/your/repo
```

会：

- 把 manifest 中的 rules/skills 复制到 `.cursor/rules/`、`.cursor/skills/`（**扁平目录**）
- **不删除**项目自有 `project-overview`、`vln-*` 等
- 首次安装 `.cursor/hooks.json` + `.cursor/scripts/pull-cursor-config.sh`（之后每次 Agent 会话自动 `git pull` + 合并）

## Windows 本地项目

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\cursor-personal-config\scripts\install-to-project.ps1" -ProjectRoot "D:\your\project"
```

## sync-manifest.json

列出的文件才会覆盖；增删个人 rules/skills 时同步改 manifest 并 publish。

## 汇报文档（日报/知识库）

与 Cursor 配置分开，**工作正文不进此仓库**（含实机数据），终稿在本机 `D:\Documents\`。

| 类型 | 命名 | 本机路径 |
|------|------|----------|
| 日报 | `YYYY-MM-DD-<主题>日报.md` | `D:\Documents\工作汇报\日报\` |
| 经验长文 | `YYYY-MM-DD-<主题>经验总结.md` | `D:\Documents\知识库\每日经验\` |
| 日索引 | `YYYYMMDD.md`（5–15 行入口） | 同上 |
| 索引表 | `每日清单.md` | `D:\Documents\知识库\索引\` |

Remote-SSH 暂存：`<项目根>/.cursor/工作存档/`（结构同上），写完用本机 `pull-reports-to-local.ps1` 拉回。

写法规范见 skill `daily-report` → `experience-summary-guide.md`（日报 vs 经验总结、长文模板、自检清单）。
