---
name: knowledge-lifecycle
description: >-
  Maintains a durable multi-project workflow from project state and investigation
  evidence through daily reporting, reusable experience extraction, personal
  Cursor config publication, and installation. Use when coordinating multiple
  projects, deciding where work records belong, writing daily reports or
  experience summaries, updating project memory, or evolving rules and skills.
---

# 多项目知识与工作记录闭环

## 1. 目标与边界

目标是让每项事实都有唯一主存放位置，并形成可恢复、可汇报、可复用的闭环。个人配置仓只存可公开、跨项目的方法论；它不存项目事实或日报正文。

```text
项目事实 → 项目状态/决策/调查
         ↓ 当日取材
统一日报 + 每日经验 → 本机归档中心
         ↓ 可迁移、经证据支持的方法
个人配置真源 → 校验/同步清单 → 安装到项目
```

## 2. 唯一归属

| 内容 | 主位置 | 禁止放置 |
|---|---|---|
| 当前目标、已验证、风险、下一步 | `<project_root>/docs/PROJECT_STATE.md` | 聊天摘要、日报代替状态 |
| 长期架构/接口/部署选择 | `<project_root>/docs/decisions/ADR-YYYYMMDD-<topic>.md` | 日报正文 |
| 实验、故障、否证证据 | `<project_root>/docs/investigations/<topic>.md` | 只留终端滚屏 |
| 当天跨项目管理汇报 | 本机 `工作汇报/日报/` | 每个项目各写一份日报 |
| 可复现实验经验 | 本机 `知识库/每日经验/` | 个人配置仓 |
| 每日经验导航 | 本机 `知识库/索引/每日清单.md` | 单独索引型经验正文 |
| 通用规则与 SOP | `~/.cursor-personal-config/rules|skills` | 项目副本或日报 |

远程工作时，统一暂存根为 `<workspace_root>/.cursor/工作存档/`；完成后同步到本机归档中心。若当前工作区就是本机归档中心所在工作区，仍采用该统一根，不在各项目 `.cursor` 建平行归档。

## 3. 每次开始与收尾

### 开始项目工作

1. 确定实际项目根；第三方依赖、模型缓存和嵌套 vendor 仓不是项目根。
2. 读取 `AGENTS.md`、`docs/PROJECT_STATE.md`、关联 ADR/调查；没有跨会话需求时不强建文档。
3. 对影响架构、验证结论或下一步的工作，先写可证伪假设和验收条件。

### 项目内落盘

| 变化 | 更新动作 |
|---|---|
| 普通进展 | 更新 `PROJECT_STATE.md` |
| 持久决策 | 新增 ADR，状态文件链接到它 |
| 失败或实验结论 | 更新 investigation，状态文件写结论和下一步 |
| 无法验证 | 在状态文件标记阻塞、环境角色和证据位置 |

不得把完整原始日志粘入状态文档；保留可复现命令、关键字段和受控证据位置。不得在文档写 IP、账号、密码、Token 或私有数据。

### 每日跨项目收尾

1. 列出当天实际涉及的项目；从每个项目收集状态、Git diff/status、终端、远端日志和结构化结果。
2. 先更新受影响项目的项目记录，再写一份日报和一篇经验总结。
3. 日报按项目分节，报告已验证结果、问题和下一步；经验按方法卡和实验环写，跨项目共用的方法可合并说明。
4. 统一归档命名为 `YYYY-MM-DD-<跨项目主题>日报.md` 与 `YYYY-MM-DD-<跨项目主题>经验总结.md`，更新 `每日清单.md`。
5. 同步终稿到本机并验证文件存在、UTF-8 无 BOM、无 U+FFFD/四连问号；没有本机同步证据时标记“远端暂存”。

## 4. 经验升级决策

```text
新结论是否跨项目/跨硬件仍有用？
  ├─ 否 → 留在项目状态、ADR 或 investigation
  └─ 是 → 是否有可复现证据、边界和反例？
       ├─ 否 → 先留每日经验，待补验证
       └─ 是 → 约束一句话可表达？
            ├─ 是 → rule
            └─ 否 → skill（决策树、SOP、门禁、反模式）
```

升级前去除项目名、绝对路径、原始日志和敏感信息；保留适用条件、失败原因和验收门禁。日报不是 skill 的素材粘贴目标，日报中的结论必须先抽象为方法论。

## 5. 个人配置发布与安装

1. 只在 `~/.cursor-personal-config` 编辑真源；项目 `.cursor` 是安装副本。
2. 新增/删除 rule 或 skill 时更新 `sync-manifest.json`；README 列出新增 skill。
3. 含中文文档必须跑 UTF-8/CJK 校验；检查隐私和 manifest 范围。
4. 按 `cursor-config-sync` 安装到本次涉及项目；安装后检查 `<project_root>/.cursor/global-sync-manifest.json` 含新增项。
5. 用户明确要求 commit/push 时，再按 Git 流程提交和发布；无明确请求时保留在真源工作区并如实说明。

## 6. 验收清单

- [ ] 每个项目事实只在一个项目记录位置有主副本。
- [ ] 当天只有一套统一日报与经验，不因项目数复制多套。
- [ ] 日报和经验能链接回项目状态/调查，但不复制完整日志。
- [ ] 每项“已验证”有测试、日志字段、提交或文件证据。
- [ ] 每项失败路径写清前提、现象和替代方向。
- [ ] 被升级的 rule/skill 已完成隐私、编码、同步清单和安装验证。

## 7. 反模式

| 反模式 | 为什么失败 | 正确做法 |
|---|---|---|
| 所有文档都放每个项目 `.cursor` | 多项目时重复、分散且易被安装覆盖 | 项目事实入 `docs/`，日报经验入统一归档 |
| 日报代替项目状态 | 下一次不能快速恢复具体项目 | 项目状态与日报同步更新，各自服务不同读者 |
| 聊天总结代替证据 | 跨会话不可检索，也无法审计 | 命令和关键字段落入 investigation |
| 发现一次经验就加 rule | 会积累无证据禁令 | 先在项目/每日经验验证，再抽象升级 |
| 只改项目 `.cursor` | 其他项目和机器无法获得更新 | 改真源、更新 manifest、安装验证 |

## 8. 相关

- 项目状态与交接：`project-continuity`
- 日报与经验写法：`work-reporting-pipeline`、`daily-report`、`daily-knowledge-base`
- 现场证据：`remote-ssh-dev`、`field-validation-method`
- 配置发布：`author-cursor-config`、`cursor-config-sync`
- 中文和隐私：`utf8-chinese-docs`、`privacy-github`
