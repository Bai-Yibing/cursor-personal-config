---
name: weekly-report
description: >-
  DEPRECATED. Weekly leadership reports are discontinued. If the user asks for
  周报 or 本周收尾, do not generate a weekly file; point them to daily 日报 and
  self-contained 每日经验总结 instead.
disable-model-invocation: true
---

# 周报（已废弃）

**本 skill 已停用。** 用户明确要求：只保留 **日报 + 每日经验总结**，不再自动或按流程生成周报。

若用户说「写周报 / 本周收尾 / 本周总结」：

1. 说明周报流程已取消。
2. 引导改用 `daily-report` + `daily-knowledge-base`（按日翻阅；跨天回顾则人工读多日长文）。
3. **不要**创建 `工作汇报/周报/` 或 `知识库/每周汇总/` 下的新文件。

详见 `work-reporting-pipeline` 与 `daily-report/experience-summary-guide.md`。
