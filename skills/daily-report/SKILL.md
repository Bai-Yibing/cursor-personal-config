---
name: daily-report
description: >-
  Generate leadership 日报 and reproducible personal experience summaries
  (lab-notebook style with method cards). Use when the user asks for 日报,
  daily summary, 今日总结, 经验总结, 知识库, or end-of-day report. Do not produce
  weekly reports or elevate YYYYMMDD.md stubs into experience bodies.
disable-model-invocation: true
---

# 日报与每日经验总结

## 两类文档，两种读者（不可混写）

| 产出 | 读者 | 原则 |
|------|------|------|
| **日报** | **领导** | 做了什么、为什么、结果如何；一页为佳 |
| **每日经验总结** | **自己** | **离线可复现**；方法卡 + 实验环 + 有边界结论 |

经验详细写法见 [experience-summary-guide.md](experience-summary-guide.md)（零号门禁、方法卡、文风）。

**不产出周报 / 周汇总。**  
**不要求**把 `YYYYMMDD.md` 写成经验正文；该类文件若存在，仅作导航占位，链到长文与 `每日清单.md`。

## 收集材料（必须主动执行）

本地 + 远程双端，缺什么查什么：

1. 本机 transcripts：`$env:USERPROFILE\.cursor\projects\*\agent-transcripts\*.jsonl`
2. 本机 terminals（含 ssh 输出）：`$env:USERPROFILE\.cursor\projects\*\terminals\*.txt` → 经验文嵌入关键输出
3. 代码变更（在实际改动的机器上）：`git log` / `git diff`；经验文嵌入关键改前/改后或 hunk
4. 远端日志与评测：见 `remote-ssh-dev` → `remote-materials.md`；`summary.json` / COMPARE 字段原文进正文
5. 用户补充的日志、口述现象（标 `[用户口述]`）

正文用主机角色占位：`<perception_host>` / `<robot_host>` / `<ptq_host>`。

## 输出结构（日报）

```text
YYYYMMDD
今日总结
第一，……
第二，……
第三，……

存在问题
1. ……

明日待办
1. ……
```

## 行文要求（日报）

- 固定使用既有领导版结构：`YYYYMMDD`、`今日总结`、`存在问题`、`明日待办` 四段；不要改写成 Markdown 标题式报告。
- `今日总结`按“第一、第二、第三……”写当天最重要的进展、原因和结果；失败、阻塞和证据不足写进「存在问题」；下一步只写进「明日待办」。
- 日报不放“项目记录”“主机覆盖台账”“材料索引”“结果总表”“方法卡”等经验文档章节。主机覆盖台账只作为取材过程记录；需要向读者说明时，在「存在问题」用一句话说明覆盖是否完整。
- 简体中文；先现象后根因；能量化就量化。
- 领导可读：少堆代码块、命令和 commit hash；一页为佳。

## 经验总结（生成时）

按 `experience-summary-guide.md`：

1. 总问题与主指标  
2. 方法卡（背景 → 原因 → 改前/改后代码或「待补」→ 参考）  
3. 实验时间线  
4. 误判与否证  
5. 普适结论（主张 / 前提 / 证据 / 不适用 / 置信度）  
6. 仍未知  

文风：实验笔记，不审查腔。无证据不编造；缺 diff/日志写「待补 + 主机角色 + 路径」。

## 保存（本机为准）

| 文件 | 本机路径 |
|------|----------|
| 日报 | `D:\Documents\工作汇报\日报\YYYY-MM-DD-<主题>日报.md` |
| 经验长文 | `D:\Documents\知识库\每日经验\YYYY-MM-DD-<主题>经验总结.md` |
| 文件夹导航 | `D:\Documents\知识库\索引\每日清单.md` |

远端暂存：`<项目根>/.cursor/工作存档/` → 写完 `pull-reports-to-local.ps1`。

写完日报后：用户曾要求「每天都要」则直接写经验长文；否则主动问是否同步生成。

## 交付前自检

### 日报

- [ ] 首行是 `YYYYMMDD`，并且只有「今日总结 / 存在问题 / 明日待办」三块正文
- [ ] 今日总结使用“第一、第二……”；存在问题写失败/阻塞/待验证；明日待办可执行
- [ ] 没有“项目记录、主机覆盖台账、材料索引、方法卡、结果总表”等经验章节；本机文件存在

### 经验

- [ ] 零号门禁五件套；方法卡齐全；至少一轮含“假设→预期→Setup→Result→判断更新”
- [ ] 每个关键改动有改前/改后代码或 unified diff；没有 diff 时明确写“待补 + 主机角色 + 路径”
- [ ] 关键数字有字段出处；无材料索引/dump；结论有边界和置信度
- [ ] 文风可读；本机长文存在；无真实 IP/凭据

## 参考

- 日报示例：[examples.md](examples.md)
- 经验硬标准：[experience-summary-guide.md](experience-summary-guide.md)
