---
name: daily-knowledge-base
description: >-
  Write reproducible personal experience summaries (lab-notebook / research-log
  style): method cards with before/after code, experiment loops, raw log
  fields, and bounded conclusions. Use when the user asks for 经验总结, 知识库,
  技术沉淀, daily notes, or post-mortem beyond 日报. Do not generate weekly
  rollups or treat YYYYMMDD.md as experience bodies.
disable-model-invocation: true
---

# 每日经验知识库

**读者是自己，不是领导。** 与日报不可混写、不可互相替代。

写法硬标准见 `daily-report` → [experience-summary-guide.md](../daily-report/experience-summary-guide.md)。  
**不写周报 / 周汇总。不要求短索引正文。禁止材料索引节。**

## 核心原则

1. **零号门禁**：为何 / 代码改动 / 命令 / 原始日志字段 / 普适结论。  
2. **方法卡**：背景 → 原因 → 方法（完整改前/改后，缺则「待补」）→ 参考。  
3. **实验环**：假设 → 预期 → Setup → Result → 判断更新。  
4. **结论五要素**：主张 / 成立前提 / 本轮证据 / 不适用 / 置信度。  
5. **文风**：实验笔记；忌审查腔与标签堆砌（见指南「文风」节）。  
6. **不编造**：无 diff/日志就写待补（主机角色 + 路径），禁止假数字。  
7. **证据不足分档**：结构仍对齐样板；深度按材料上限（深改 / 骨架 / 空档诚实占位）。

## 推荐结构

```text
# YYYY-MM-DD 经验总结：<主题>
## 1. 总问题与主指标
## 2. 方法卡
## 3. 实验时间线
## 4. 误判与否证
## 5. 普适结论
## 6. 仍未知
```

## 收集材料

遵循 `remote-ssh-dev` → `remote-materials.md`。日报只对齐主题，经验禁止写成日报加长版。

## 输出

- 长文：`D:\Documents\知识库\每日经验\YYYY-MM-DD-<主题>经验总结.md`  
- 远端暂存：`<项目根>/.cursor/工作存档/知识库/每日经验/`  
- 导航：`知识库/索引/每日清单.md`（可含「样板对齐」列；不是经验正文）  
- `YYYYMMDD.md`：仅导航占位，不升格为经验

## 中文编码

Windows 写含中文 md：用 UTF-8 Python / `\uXXXX` 生成脚本；写后校验无 `????`。  
禁止 PowerShell `Set-Content` 默认编码写中文。脚本字符串里勿写 `\near_` 这类会被当成换行转义的片段。

## 交付前自检

- [ ] 六段结构或诚实空档/骨架说明  
- [ ] 方法卡 + 含预期的实验环；关键字段有出处  
- [ ] 无材料索引 / dump；结论有边界；本机终稿存在  
