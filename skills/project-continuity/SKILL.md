---
name: project-continuity
description: >-
  Establish and maintain durable project context across Cursor sessions: current
  state, architecture decisions, reproducible investigations, failed approaches,
  verification evidence, and handoff notes. Use when starting a project, taking
  over an existing project, resuming work after context loss, tracking progress,
  recording a debugging outcome, or preparing a handoff.
---

# 项目连续性与项目记忆

## 1. 目标

将项目事实保存在项目仓库中，而非聊天上下文或个人配置仓。记录必须让下一位 Agent 或开发者能回答：系统如何工作、当前做到哪里、为何这样决策、什么已验证、哪些路径已失败、接下来做什么。

个人配置仓只分发本 Skill 和 Rule；项目状态、日志、截图、地址、账号、密钥及客户数据只留在受控项目环境。

## 2. 分层模型

```text
<project_root>/
├── AGENTS.md                         # 入口、边界、运行/验证约定（可选）
└── docs/
    ├── PROJECT_STATE.md               # 活跃摘要，短且当前
    ├── decisions/                     # 重要且可追溯的决策
    └── investigations/                # 故障与实验的可复现证据
```

- `PROJECT_STATE.md` 是每次恢复工作的首读文件，不复制原始日志。
- `decisions/` 只记录会影响后续实现、部署或接口的选择及理由。
- `investigations/` 记录假设、改动、验证命令、关键输出字段、否证和结论边界。
- 已完成且不再影响当前行动的细节，压缩为一行历史并保留相关文件链接。

## 3. 建档决策

```text
需要跨会话/跨人跟进，或任务含多个阶段？
  ├─ 否：只在必要时更新现有项目文档，不新建记忆体系。
  └─ 是：读取已有 AGENTS.md / PROJECT_STATE.md。
       ├─ 文件存在：核实是否仍反映代码、运行环境和未决问题。
       └─ 文件不存在：创建最小 PROJECT_STATE.md；复杂系统再补 AGENTS.md。

本次是否产生重要决策或可复现故障结论？
  ├─ 重要决策：新增 decisions/ADR-YYYYMMDD-<topic>.md。
  ├─ 调查结论：新增或更新 investigations/<topic>.md。
  └─ 普通实现：只更新 PROJECT_STATE.md 的进展和下一步。
```

## 4. 标准流程

### 4.1 接手或恢复

1. 读取 `AGENTS.md`、`docs/PROJECT_STATE.md`、关联决策和调查记录。
2. 用代码、Git 状态、部署机日志或测试结果核实关键断言；失效内容标注待复核。
3. 在 `PROJECT_STATE.md` 写清当前目标、阻塞条件和本次验证计划，再开始非琐碎修改。

### 4.2 执行期间

1. 先记录可证伪假设和验收条件，再修改代码或环境。
2. 运行命令只记录可复现的命令与关键输出字段；敏感参数使用占位符。
3. 失败尝试记录前提、观察到的症状、否证证据和替代方向；不要仅写“无效”。
4. 确认的架构/接口/部署决策单独成文，避免理由淹没在状态摘要中。

### 4.3 收尾与交接

1. 更新当前状态、已验证项、未验证项、风险和下一步。
2. 给下一位执行者明确入口：文件、命令、环境角色和成功判据。
3. 避免“已完成”但没有验证证据；无法验证时写明原因和阻塞。
4. 仅在用户要求时提交项目记忆文件，与代码改动一并审查。

## 5. 最小模板

### `docs/PROJECT_STATE.md`

```markdown
# Project State

## Purpose and boundaries
- Goal:
- In scope / out of scope:
- Runtime and integration points:

## Current focus
- Active objective:
- Completed and verified:
- In progress:
- Blockers and risks:

## Durable facts
- [fact] Evidence: <test, log field, commit, or file>

## Do not repeat
- [failed approach] Preconditions, observed result, and alternative: <investigation link>

## Next actions
1. <action and acceptance criterion>

## Handoff
- Last updated: <YYYY-MM-DD>
- Resume from:
```

### `docs/investigations/<topic>.md`

```markdown
# Investigation: <topic>

## Question and hypothesis
## Environment and constraints
## Expected result
## Changes and commands
## Evidence
## Result and interpretation
## Failed approaches and why
## Decision / next experiment
## Confidence and limits
```

### `docs/decisions/ADR-YYYYMMDD-<topic>.md`

```markdown
# ADR: <decision>

## Context
## Decision
## Alternatives considered
## Consequences
## Evidence and rollback
```

## 6. 验收门禁

- 当前状态能在不读聊天记录的情况下恢复下一步工作。
- 每项“已验证”都有测试、日志字段、提交或文件证据。
- 每项失败路径含适用条件、观察结果和替代路径。
- 记录不包含 IP、账号、密码、Token、原始私有日志或个人绝对路径。
- 活跃状态摘要保持短小；历史细节归档到决策或调查文件。

## 7. 反模式

| 反模式 | 为何失败 | 正确做法 |
|---|---|---|
| 将聊天摘要当唯一项目记忆 | 新会话和多人无法稳定获取 | 写入项目版本化文档 |
| 将完整终端输出粘进状态文件 | 噪声膨胀且可能泄密 | 保留命令、关键字段和受控证据位置 |
| 只记录成功方案 | Agent 会重复失败尝试 | 记录失败前提、症状和否证 |
| 无证据宣称完成 | 后续无法判断可信度 | 明确验证、未验证和阻塞 |
| 每个小改动新增 ADR | 文档成本超过价值 | 只为持久、影响广的决策建 ADR |

## 8. 相关

- 远端运行与取材：`remote-ssh-dev`
- 现场证据与验收：`field-validation-method`
- 日常经验沉淀：`daily-knowledge-base`
- 公开配置发布：`author-cursor-config`、`cursor-config-sync`
- 脱敏要求：`privacy-github`
