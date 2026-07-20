---
name: weekly-knowledge-base
description: >-
  Automatically aggregate and synthesize the week's daily knowledge-base entries
  into a weekly technical summary with cross-day logic, consolidated metrics,
  and trend analysis. Use when the user asks for 周经验汇总, 每周知识库总结,
  周度技术沉淀, or when generating 周报 and weekly knowledge rollup together.
disable-model-invocation: true
---

# 每周知识库汇总

**自动**读取本周全部每日经验文件，做跨天归纳——不是拼接，是**提炼主线、合并数据、追踪问题演化**。

## 触发时机

- 用户说「写周经验汇总」「每周知识库总结」
- 用户说「写周报」时：**必须同步生成本 skill 输出**（与 weekly-report 并行）
- 每周五或用户说「本周收尾」时，主动提示是否生成周汇总

## 收集材料（必须全部读取）

1. **本周每日知识库**：`D:\Documents\知识库\每日经验\` 内日期落在本周的 `*.md`
2. **每日清单索引**：`D:\Documents\知识库\索引\每日清单.md`（若有）
3. **本周日报**（辅助对齐）：`D:\Documents\工作汇报\日报\`
4. **兜底**：本周 transcripts、terminals、**远端 git/日志**（每日 KB 缺失时；见 `remote-ssh-dev` → remote-materials.md）

先列出读到的文件清单、日期覆盖及**涉及远程主机**；有缺口在文首「材料缺口」写明。

## 汇总方法

### 第一步：按主题聚类
将多天条目按**技术主题**合并（如「定位融合」「撞墙排查」「暖机安全」），不按日期机械堆砌。

### 第二步：梳理周度逻辑主线
每个主题写一条**周度推理链**：
```text
周一：现象 A，假设 H1，验证后 …
周三：新数据推翻/支持 H1，转向 H2 …
周五：方案 S 落地，指标从 X 到 Y …
→ 周结论：…（置信度 + 关键证据）
```

### 第三步：合并指标表
把各天测试表合并为**周度总表**，并算：
- 最好/最差/中位数（有 3 轮以上时）
- 周环比：相对上周或本周初的代表性改善（有数据才写）

### 第四步：问题演化追踪
| 问题 | 周一状态 | 周中变化 | 周末状态 | 证据摘要 |
|------|----------|----------|----------|----------|

### 第五步：未解项与下周实验设计
每个未解问题：已知事实、排除项、待验证假设、建议实验（含验收指标）。

## 输出结构

文件名：`D:\Documents\知识库\每周汇总\YYYYWW.md` 或 `YYYYMMDD-YYYYMMDD.md`

```markdown
# YYYYWW 周度经验汇总（YYYY-MM-DD ~ YYYY-MM-DD）

## 材料来源
- 纳入的每日文件：（列表）
- 缺口：（无则写「无」）

## 本周技术主线（3–5 条）
### 主线一：…
（周度逻辑脉络 + 关键数据 + 证据索引）

## 周度指标汇总
| 主题 | 主机 | 测试次数 | 最佳 | 最差 | 趋势 | 数据来源日期 |
|------|----------|------|------|------|--------------|

## 问题演化
（表格 + 简短分析）

## 本周确定结论（有据）
1. … `[证据：日期+日志/指标]`

## 本周待验证假设
1. H…：验证方法、验收标准

## 代码/配置变更周志
| 日期 | 主机 | 变更 | 路径（远端 Linux） | 影响 |

## 经验教训（可复用）
- …

## 关联
- 领导版周报：`D:\Documents\工作汇报\周报\YYYYWW.md`
```

## 索引更新

生成后更新本机 `D:\Documents\知识库\索引\每日清单.md`（远端写的须 pull 后更新）。

## 保存（本机为准）

| 本机终稿 | 远端暂存 |
|----------|----------|
| `D:\Documents\知识库\每周汇总\YYYYWW.md` | `<project_root>/.cursor/工作存档/知识库/每周汇总/YYYYWW.md` |

写完执行 `pull-reports-to-local.ps1`；详见 `save-work-reports.md`。

## 交付前自检

- [ ] 已读取本周全部每日 KB，非选择性摘抄
- [ ] 跨天叙述是「演化」而非「日记拼接」
- [ ] 合并指标表有数据来源日期
- [ ] 结论均带证据索引；无证据的标为「假设」
- [ ] **本机** `D:\Documents\知识库\每周汇总\YYYYWW.md` 已存在
