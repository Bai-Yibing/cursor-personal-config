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

日报给领导。下面三块是**日报正文**，不是所有汇报体裁；经验总结另走方法卡。

正文固定三块：今日总结、存在问题、明日待办。

- 今日总结用「第一，」「第二，」……中文序数起段。
- 存在问题和明日待办用「1. 」「2. 」……
- **条数跟当天内容走。**「一二三」只是举例：不要凑满三条，也不要卡死三条。

写之前必须再扫当天全部工作记录（项目状态、调查、现场进程、git、评测数字），不要只改上一版日报的字。并行交差线各写一条。

```text
YYYYMMDD
今日总结
第一，……
第二，……
第四，……   # 有几条写几条

存在问题
1. ……
2. ……

明日待办
1. ……
```

分条原则：

1. **一条一事**：同一交差目标（同一产品线或同一已拍板结论）一条。并行梯子分开写，不要把几条线捏进同一「第 N」。
2. 每条写满：目标、做了什么、关键数字、证明了什么/没证明什么、已拍板决策。领导应能只读这一条就懂边界。
3. 失败配方、校准刀、命令与方法实验不进日报；一句「试过 X，已停」即可。细节进调查或经验。
4. 进度条到 100% 不等于产物出盘；主机仿真过不等于板上过。

## 行文要求（日报）

- 读者是领导：白话先于作业名；少堆代码、命令、commit。不要压成三句黑话，也不要拆成多章技术报告。
- 能量化就量化；无证据标待验证。
- 失败、阻塞、待验证放「存在问题」；下一步只放「明日待办」。
- 不放方法卡、主机取材台账、材料索引、原始日志 dump。覆盖不完整在存在问题里一句话说明。
- 情报简报走 `industry-watch`，不把空窗扫描写成工作成果。

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

- [ ] 写前已扫当天全部工作记录，不是只改上一版日报
- [ ] 正文是「今日总结 / 存在问题 / 明日待办」；总结用第一、第二，后两块用 1. 2.；条数跟内容走，不凑、不卡死三条
- [ ] 一条一事，并行交差线未捏成一条
- [ ] 每一条能单独读懂（目标、结果、证明边界），不是三句黑话
- [ ] 没有把进度条 100% 写成已出盘；没有把空窗情报写成工作成果
- [ ] 没有主机台账、材料索引、方法卡、原始日志 dump；本机或远端暂存文件存在

### 经验

- [ ] 零号门禁五件套；方法卡齐全；至少一轮含“假设→预期→Setup→Result→判断更新”
- [ ] 每个关键改动有改前/改后代码或 unified diff；没有 diff 时明确写“待补 + 主机角色 + 路径”
- [ ] 关键数字有字段出处；无材料索引/dump；结论有边界和置信度
- [ ] 文风可读；本机长文存在；无真实 IP/凭据

## 参考

- 日报示例：[examples.md](examples.md)
- 经验硬标准：[experience-summary-guide.md](experience-summary-guide.md)
