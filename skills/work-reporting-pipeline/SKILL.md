---
name: work-reporting-pipeline
description: >-
  End-to-end daily work reporting: leadership 日报 plus one reproducible personal
  experience summary (method-card lab notebook). Use when the user asks to 写日报,
  写经验总结, 今日收尾, or set up the daily reporting workflow. Weekly reports
  are discontinued; YYYYMMDD.md is navigation-only.
disable-model-invocation: true
---

# 工作汇报流水线

仅保留 **日报 + 每日经验总结（长文）**。不写周报、不写每周知识库汇总。  
`YYYYMMDD.md` 若存在：仅导航占位，不写经验正文。

## 每日收尾

| 步骤 | Skill | 输出 |
|------|-------|------|
| 1 | `daily-report` | `D:\Documents\工作汇报\日报\YYYY-MM-DD-<主题>日报.md` |
| 2 | `daily-knowledge-base` + `experience-summary-guide.md` | `YYYY-MM-DD-<主题>经验总结.md` |

规则：

- 先搜集材料（transcripts/terminals + 远端 git/日志/`summary.json`），再写。  
- 经验 = 方法卡 + 实验环 + 原始字段 + 有边界结论；详见 experience-summary-guide.md。  
- 禁止材料索引节、dump 附录、日报加长版、编造 diff/数字。  
- 可更新 `每日清单.md`（日期 / 主题 / **样板对齐** / 文件）。对齐取值：`样板已认可` / `已样板对齐` / `空档`。

用户只说「写日报」：写完后主动问是否生成经验；用户曾说「每天都要」则直接生成。  
用户若说「写周报 / 本周收尾」：拒绝，改为按日翻阅。

## 目录

```text
D:\Documents\
├── 工作汇报\日报\
└── 知识库\每日经验\ / 索引\每日清单.md

<workspace_root>/.cursor\工作存档\   ← Remote-SSH 统一暂存
```

禁止：`周报/`、`每周汇总/`、专题旁路目录冒充知识库。

## 远程保存

1. 写入统一工作存档；多项目当天只写一套，按项目分节
2. `pull-reports-to-local.ps1`
3. 确认本机文件存在

## 全库改造时

结构与文风对齐样板；证据深度按材料上限。空档日诚实占位，不伪造方法卡。
