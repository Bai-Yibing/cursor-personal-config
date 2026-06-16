---
name: weekly-report
description: >-
  Automatically generate weekly reports (周报) for leadership by aggregating all
  daily reports and daily knowledge-base entries from the week. Use when the
  user asks for 周报, 本周总结, or end-of-week report. Always pair with
  weekly-knowledge-base for the technical rollup.
disable-model-invocation: true
---

# 周报生成（自动汇总）

**自动**读取本周全部日报与知识库，归纳后输出领导版周报；**必须同步**调用 `weekly-knowledge-base` 生成技术周汇总。

## 自动汇总流程（严格执行）

```text
1. 扫描 D:\Documents\工作汇报\日报\  → 本周全部 YYYYMMDD.md
2. 扫描 D:\Documents\知识库\每日经验\  → 本周全部 *.md
3. 若日报缺失但知识库有 → 从知识库提炼领导可读摘要，标注「日报缺失，由知识库补」
4. 若两者皆缺某天 → 回退 transcripts / terminals / **远端 git·日志** 补洞（见 remote-materials.md）
5. 按主题合并（非按天罗列）→ 输出周报
6. 并行输出 weekly-knowledge-base 周度技术汇总
```

## 收集材料

| 优先级 | 来源 | 用途 |
|--------|------|------|
| 1 | 本周日报 `D:\Documents\工作汇报\日报\` | 领导视角、待办、问题 |
| 2 | 本周知识库 `D:\Documents\知识库\每日经验\` | 数据、证据、逻辑链 |
| 3 | 上周周报 `D:\Documents\工作汇报\周报\` | 对照「上周待办」完成情况 |
| 4 | transcripts / terminals / **远端各 Host 的 git·日志** | 兜底；见 `remote-ssh-dev` |

跨机工作按**主题**合并；周度指标注明涉及的主机（S100、Go2-SSH 等）。

## 输出结构

```text
YYYYWW（YYYY-MM-DD ~ YYYY-MM-DD）
本周总结
第一，……（周度主线：从问题发现 → 方案 → 验证，带关键数字）
第二，……
第三，……
（3–6 条，按课题非按天）

本周关键成果
- ……（可量化；注明「本周最佳：X」）

存在问题
1. ……（合并同类；跨天反复的问题标「持续」）

下周待办
1. ……（可验收标准；与本周未解问题对应）

---
附：技术详版见 D:\Documents\知识库\每周汇总\YYYYWW.md
```

## 汇总规则

- **数据优先从知识库取**：日报数字与知识库冲突时，以知识库证据表为准，并在周报脚注说明。
- **上周待办对照**：上周「下周待办」逐条标完成/部分/未完成 + 一句依据。
- **避免流水账**：不写「周一…周二…」，写「本周前期…后期…」或按技术线。
- **有理有据**：每条「本周总结」至少含 1 个可量化结果或前后对比。
- **诚实**：本周失败轮次、未达标指标写入「存在问题」。

## 与日报 / 知识库的关系

| 产出 | 路径 | 读者 | 详度 |
|------|------|------|------|
| 日报 | `工作汇报/日报/` | 领导 | 日 |
| 周报 | `工作汇报/周报/` | 领导 | 周 |
| 日知识库 | `知识库/每日经验/` | 自己/团队 | 日，全证据 |
| 周知识库 | `知识库/每周汇总/` | 自己/团队 | 周，跨天演化 |

## 保存（本机为准）

见 `save-work-reports.md`（`C:\Users\19944\.cursor\scripts\`）。

| 文件 | 本机终稿 | 远端暂存 |
|------|----------|----------|
| 周报 | `D:\Documents\工作汇报\周报\YYYYWW.md` | `/root/vln/.cursor/工作存档/工作汇报/周报/YYYYWW.md` |
| 周知识库 | `D:\Documents\知识库\每周汇总\YYYYWW.md` | `/root/vln/.cursor/工作存档/知识库/每周汇总/YYYYWW.md` |

汇总时**优先读本机** `D:\Documents\`；若缺文件先 `pull-reports-to-local.ps1` 从远端拉回再汇总。

写完执行 pull；交付前确认本机两份文件均已存在。

## 交付前自检

- [ ] 本周每日报/知识库已全量扫描，文首有材料清单
- [ ] 已对照上周待办
- [ ] 已同步生成 weekly-knowledge-base
- [ ] 无编造；缺口已标注
- [ ] **本机** `D:\Documents\` 下周报与周知识库文件均已存在
