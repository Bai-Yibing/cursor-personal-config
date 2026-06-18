---
name: daily-report
description: >-
  Generate daily work reports (日报) for leadership and daily experience
  summaries (每日经验总结) with data tables and evidence chains. Use when the user
  asks for 日报, daily summary, 今日总结, 经验总结, 知识库, or end-of-day report.
disable-model-invocation: true
---

# 日报与每日经验总结

## 两类文档，两种读者（不可混写）

| 产出 | 读者 | 原则 |
|------|------|------|
| **日报** | **领导** | 说清做了什么、为什么、结果如何；技术适度；一页为佳 |
| **每日经验总结** | **自己** | **足够详细**；**完整数据支撑**；**可靠经验**；**可信结论** |

日报写给领导：便于汇报与决策，不堆砌日志与代码路径。

经验写给自己：三个月后仍能凭文档还原当天、复现判断、避免重复踩坑。**宁可多写有出处的细节，不要用「已修复」糊弄未来的自己。** 详细写法见 [experience-summary-guide.md](experience-summary-guide.md)。

生成经验总结时，**默认写长文**（非日报的加长版）；`YYYYMMDD.md` 短索引仅作入口，不可替代长文。

## 收集材料（必须主动执行）

按顺序搜集当日信息；**本地 + 远程 SSH** 双端，缺什么就查什么：

1. **对话历史**（本机）：`C:\Users\19944\.cursor\projects\*\agent-transcripts\*.jsonl`
2. **终端记录**（本机，含 `ssh` 会话输出）：`C:\Users\19944\.cursor\projects\*\terminals\*.txt`
3. **代码变更**（在**实际改动的仓库所在机器**上）：
   - Remote-SSH 工作区：直接 `git log` / `git diff`
   - 否则：`ssh <Host> 'cd <repo> && git log --since="今天0点" --oneline && git diff'`
4. **远程日志与测试**（当日涉及的每台主机）：见 skill `remote-ssh-dev` → `remote-materials.md`
5. **用户补充**：粘贴的远端日志、实机数据、截图说明

汇报中注明**主机名**（如 S100、Go2-SSH）；跨机工作按主题合并，不按 ssh 会话机械罗列。

## 输出结构（严格遵循）

```text
YYYYMMDD
今日总结
第一，……
第二，……
第三，……
（按实际条目增减，用「第一、第二、第三…」）

存在问题
1. ……
2. ……

明日待办
1. ……
2. ……
```

## 行文要求

- 用**简体中文**；「今日总结」每条是一个完整工作块（排查 / 开发 / 实机 / 修 bug 等），块内按**时间或因果**叙述。
- **先现象后根因**：例如「一开始怀疑 X，日志显示 Y，真正问题是 Z」。
- **量化**：时长、距离、比例、次数、轮次、参数值——有数据就写，没有则标注「待补数据」。
- **对比**：改前/改后、上午/下午、第 N 轮 vs 第 N+1 轮。
- **诚实**：失败轮次、未闭环问题写进「存在问题」，不要只写成功的。
- **领导可读**：少用未解释缩写；必要术语后跟一句白话（如「坐标变换（TF）」）。
- 不写代码块、不写 commit hash，除非领导需要；重点在**业务结果与工程判断**。

## 「今日总结」分块指南

| 块类型 | 写什么 |
|--------|--------|
| 排查 | 怀疑点 → 验证手段 → 根因 → 影响 |
| 开发 | 做了什么模块/节点 → 接到哪条流程 → 关键行为变化 |
| 实机 | 几轮、主机（S100/Go2 等）、时长/距离/地图比例 → 最好与最差一轮 |
| 修复 | 安全隐患或 bug 是什么 → 怎么改的 → 是否已验证 |

## 保存（本机为准 · 必读 save-work-reports.md）

**权威终稿必须在 Windows 本机** `D:\Documents\`：

| 文件 | 本机路径 |
|------|----------|
| 日报 | `D:\Documents\工作汇报\日报\YYYY-MM-DD-<主题>日报.md` |
| 日知识库索引 | `D:\Documents\知识库\每日经验\YYYYMMDD.md` |
| 经验总结长文 | `D:\Documents\知识库\每日经验\YYYY-MM-DD-<主题>经验总结.md` |

### Remote-SSH 工作区（在远端写时）

1. 先写远端：`<项目根>/.cursor/工作存档/工作汇报/日报/YYYY-MM-DD-<主题>日报.md`（目录不存在则创建）
2. 写完**立即**在本机执行 `pull-reports-to-local.ps1`（参数见 `work-reporting-pipeline`）
3. 自检：本机 `D:\Documents\工作汇报\日报\YYYY-MM-DD-<主题>日报.md` 已存在且非空

### 本机工作区

直接写入 `D:\Documents\...`。

用户指定路径时以用户为准，但**仍须同步一份到** `D:\Documents\`。

写完日报后同步或询问是否生成当日知识库；知识库同样须 pull 到本机。生成经验总结时**同时**写长文 + `YYYYMMDD.md` 短索引（见 experience-summary-guide.md）。

## 交付前自检

### 日报

- [ ] 日期标题格式 `YYYYMMDD`
- [ ] 三块齐全：今日总结 / 存在问题 / 明日待办
- [ ] 明日待办具体可执行（含「对比」「再跑 N 分钟」「确认 X」类动作）
- [ ] 无编造：材料里没有的实验结论标为待验证
- [ ] **本机** `D:\Documents\工作汇报\日报\YYYY-MM-DD-<主题>日报.md` 已存在（远端写的须已 pull）

### 每日经验总结（写给自己，标准高于日报）

- [ ] **足够详细**：时间线、怀疑→否定过程、改前改后；篇幅明显长于日报
- [ ] **完整数据**：多轮总表 + 数字出处；矛盾已解释
- [ ] **可靠经验**：可复用排查步骤；无效尝试与误判已写
- [ ] **可信结论**：独立结论节，每条有依据 + 置信度；未验证不写成定论
- [ ] 短索引 `YYYYMMDD.md` 仅链到长文，不代替长文
- [ ] **本机** `D:\Documents\知识库\每日经验\` 下长文 + 索引已 pull

## 参考示例

- 日报行文：[examples.md](examples.md)
- 经验总结结构与模板：[experience-summary-guide.md](experience-summary-guide.md)
