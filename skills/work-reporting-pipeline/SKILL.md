---
name: work-reporting-pipeline
description: >-
  End-to-end work reporting pipeline: daily report + daily knowledge base, then
  automatic weekly aggregation for both 周报 and weekly knowledge summary. Use
  when the user asks to 写日报和知识库, 今日收尾, 本周收尾, or set up the
  full reporting workflow for the day or week.
disable-model-invocation: true
---

# 工作汇报流水线

日报、知识库、周报、周汇总的**标准执行顺序**。

## 每日收尾（用户说「写日报」「今日收尾」）

按序执行，输出 **2 个文件**：

| 步骤 | Skill | 输出 |
|------|-------|------|
| 1 | `daily-report` | `D:\Documents\工作汇报\日报\YYYYMMDD.md` |
| 2 | `daily-knowledge-base` | `D:\Documents\知识库\每日经验\YYYYMMDD.md` |

规则：
- 先搜集材料（本机 transcripts/terminals + **远端各 Host** git/日志），再写；见 `remote-ssh-dev` → remote-materials.md。
- 知识库必须比日报更细：完整推理链、证据表、全轮次数据；指标含**主机**列。
- 更新 `D:\Documents\知识库\索引\每日清单.md`。

用户只说「写日报」时：写完日报后**主动问**是否同步生成当日知识库；用户曾说「每天都要」则直接生成两份。

## 每周收尾（用户说「写周报」「本周收尾」；或周五）

按序执行，输出 **2 个文件**：

| 步骤 | Skill | 输出 |
|------|-------|------|
| 1 | `weekly-knowledge-base` | `D:\Documents\知识库\每周汇总\YYYYWW.md` |
| 2 | `weekly-report` | `D:\Documents\工作汇报\周报\YYYYWW.md` |

规则：
- **先读全周每日知识库**，再写周汇总；周报从日报+周知识库提炼，不跳过周知识库。
- 对照上周周报「下周待办」完成情况。
- 更新每日清单「是否已纳入周汇总」。

## 仅补知识库 / 仅补周报

- 「只写经验总结」→ 仅 `daily-knowledge-base`
- 「只写周报」→ `weekly-knowledge-base` + `weekly-report`（两个都做）

## 目录结构（本机权威存档）

```text
D:\Documents\                          ← 终稿必须在这里
├── 工作汇报\日报\ / 周报\
└── 知识库\每日经验\ / 每周汇总\ / 索引\

/root/vln/.cursor/工作存档/            ← Remote-SSH 暂存（结构同上）
```

## 远程 SSH 保存流程

在 S100-SSH 等工作区生成日报/知识库/周报时：

1. 写入 `/root/vln/.cursor/工作存档/...`（与上表同结构）
2. 执行 `pull-reports-to-local.ps1` 拉回 `D:\Documents\`
3. 确认本机文件存在后再算完成

Hook 自动拉回：打开工作区、sessionStart、sessionEnd。

## 每日收尾

```markdown
# 每日经验索引

| 日期 | 主题关键词 | 文件 | 周汇总 |
|------|------------|------|--------|
```

新条目追加；周汇总后改「周汇总」列为「YYYYWW ✓」。
