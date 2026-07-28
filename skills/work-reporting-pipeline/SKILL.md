---
name: work-reporting-pipeline
description: >-
  End-to-end daily work reporting: leadership 日报 plus self-contained daily
  experience summary (长文 + 短索引). Use when the user asks to 写日报, 写经验总结,
  今日收尾, or set up the daily reporting workflow. Weekly reports are discontinued.
disable-model-invocation: true
---

# 工作汇报流水线

仅保留 **日报 + 每日经验总结**。不写周报、不写每周知识库汇总。

## 每日收尾（「写日报」「今日收尾」「写经验总结」）

按序执行，输出 **日报 1 份 + 知识库 2 份（长文 + 短索引）**：

| 步骤 | Skill | 输出 |
|------|-------|------|
| 1 | `daily-report` | `D:\Documents\工作汇报\日报\YYYY-MM-DD-<主题>日报.md` |
| 2 | `daily-knowledge-base` + `daily-report/experience-summary-guide.md` | 长文 `YYYY-MM-DD-<主题>经验总结.md` + 索引 `YYYYMMDD.md` |

规则：
- 先搜集材料（本机 transcripts/terminals + **远端各 Host** git/日志），再写；见 `remote-ssh-dev` → remote-materials.md。
- **经验写给自己且必须离线自包含**：关键日志摘录、diff、命令+期望输出、指标表嵌入正文；路径只做附录。详见 experience-summary-guide.md「零号门禁」。
- 短索引 `YYYYMMDD.md` 仅作入口，**不可替代长文**。
- 更新 `D:\Documents\知识库\索引\每日清单.md`。

用户只说「写日报」时：写完日报后**主动问**是否同步生成当日知识库；用户曾说「每天都要」则直接生成两份。

用户若仍说「写周报 / 本周收尾 / 周汇总」：**拒绝按周汇总流程执行**，改为提醒——请按日翻阅日报与经验总结；需要跨天回顾时人工阅读多日长文，系统不再自动产周报。

## 仅补知识库

- 「只写经验总结」→ 仅 `daily-knowledge-base`（仍须满足自包含门禁）

## 目录结构（本机权威存档）

```text
D:\Documents\                          ← 终稿必须在这里
├── 工作汇报\日报\
└── 知识库\每日经验\ / 索引\

<project_root>/.cursor/工作存档/         ← Remote-SSH 暂存（结构同上）
```

历史「周报 / 每周汇总」目录若仍存在，仅作旧档，**不再写入**。

## 远程 SSH 保存流程

1. 写入 `<项目根>/.cursor/工作存档/...`（与上表同结构）
2. 本机执行 `pull-reports-to-local.ps1` 拉回 `D:\Documents\`
3. 确认本机文件存在后再算完成

Hook 可能在打开工作区 / sessionStart / sessionEnd 时自动拉回。

## 每日清单索引格式

```markdown
# 每日经验索引

| 日期 | 主题关键词 | 文件 |
|------|------------|------|
```

新条目追加一行即可（不再维护「周汇总」列）。
