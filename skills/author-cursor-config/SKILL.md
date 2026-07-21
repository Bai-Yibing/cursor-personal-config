---
name: author-cursor-config
description: >-
  How to author and evolve personal Cursor skills and rules for the public
  cursor-personal-config repo. Use when creating or rewriting skills/rules,
  distilling field experience into playbooks, fixing skill encoding, updating
  sync-manifest, or the user asks how skills/rules should be written.
---

# Cursor Skills / Rules 撰写方法论

规范个人配置仓库（`cursor-personal-config`）的撰写与迭代。目标：**普适、可复用、可公开**，不是单次任务菜谱。

## 1. 问题定义

从实战/对话/经验总结提炼 rules/skills 时，常见失败：

- 写成某项目/型号/任务步骤（无法迁移）
- 泄露 IP、路径、凭据、客户信息
- 缺 frontmatter、缺触发词、结构散乱
- 中文编码破损（变成问号/乱码）
- 改文件但未更 `sync-manifest.json` / 未 publish

## 2. 不变量 / 第一性原理

1. **经验 → 方法论**：保留决策树、门禁、故障分类、反模式+理由；删掉单次任务专属命令/路径/型号主轴。
2. **公开可审计**：遵循 `privacy-github`。
3. **Agent 可发现**：`description` 英文第三人称，WHAT + WHEN。
4. **结构稳定**：领域 skill 用 9 段骨架；rule 用短硬约束。
5. **真源在配置仓**：Windows 可先改 `$env:USERPROFILE\.cursor\rules|skills` 再 publish；Linux / Remote-SSH **直接改** `~/.cursor-personal-config`，或把项目副本按 `sync-cursor-to-project` 反向拷回后再 push。**禁止**只改 `<project_root>/.cursor` 就当已发布。

## 3. Skill vs Rule

| 类型 | 用途 | 长度 | 触发 |
|------|------|------|------|
| Rule (`.mdc`) | 硬约束、默认行为 | 短 | `alwaysApply` / `globs` |
| Skill (`SKILL.md`) | SOP、决策树、排查模板 | 60-120 行为主，<500 | `description` 语义匹配 |

**rule 约束行为；skill 教会怎么做**。不要把长 SOP 塞进 alwaysApply rule。

## 4. 领域 Skill 9 段骨架

1. 问题定义
2. 不变量 / 第一性原理
3. 架构/选型决策树
4. 标准操作流程 SOP
5. 度量与门禁（虚荣 vs 验收）
6. 故障分类学（症状 -> 原因 -> 否证）
7. 反模式与理由
8. 交付/复盘清单
9. 相关 skills

跨领域实验方法见 `field-validation-method`。

## 5. 从经验抽象

| 做 | 不做 |
|------|------|
| 何时选 A / 何时选 B | 死绑单版参数表 |
| 虚荣指标 vs 验收指标 | 用单次覆盖率/编译成功宣称通用结论 |
| 类别词（特征 VO、激光 SLAM、静态图 NPU） | 产品名作主轴（短例可有） |
| 占位符路径/主机角色 | 真 IP、个人用户目录、内部绝对路径 |
| 反模式必写「为何失败」 | 只写「不要做 X」 |

自检：**换一个项目/硬件栈，这份 skill 还能指导行动吗？**

## 6. Frontmatter

### Skill

```yaml
---
name: skill-name
description: >-
  English third person. WHAT it does. Use when WHEN triggers...
---
```

仅当「必须用户点名」时加 `disable-model-invocation: true`。

### Rule

```yaml
---
description: one-line purpose
alwaysApply: true|false
globs: "**/*pattern*"
---
```

## 7. 隐私

禁：IP、Token/密码/串号/RTSP、个人用户目录、实机原始数据、日报正文。

允许：`<Host>` `<perception_host>` `<robot_host>` `<ptq_host>` `<project_root>` `<maps_output>` `<ptq_workspace>`；`$env:USERPROFILE` / `~`。

## 8. 编码（Windows）

1. 用 conda Python（如 Anaconda `python.exe`）写 **UTF-8 无 BOM**。
2. 易破坏时用 `\uXXXX` 生成；写后 assert 含 CJK、标题可读。
3. 不要仅信 PowerShell 控制台显示判断中文是否正常。

## 9. 发布 SOP

```text
# 推荐（Linux / Remote-SSH）
edit ~/.cursor-personal-config/rules|skills
  -> update sync-manifest.json if add/remove
  -> update README if new skill
  -> privacy grep
  -> git commit + push
  -> install-to-project.sh <project_root>

# 或（Windows）
edit USERPROFILE\.cursor\rules|skills
  -> update sync-manifest.json
  -> privacy grep
  -> publish-cursor-config.ps1
  -> git commit + push
  -> install-to-project if needed
```

若已在项目 `.cursor` 副本改过：先 `git -C ~/.cursor-personal-config pull --rebase`，再按 manifest 拷回仓内对应路径，自检后 commit/push。

## 10. 发布前门禁

- [ ] frontmatter 齐全
- [ ] 方法论化（换栈仍能用）
- [ ] 隐私清洁
- [ ] UTF-8，中文标题可读
- [ ] manifest / README 已更
- [ ] 与 `privacy-github` / `field-validation-method` 一致

## 11. 反模式

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 日报粘进 skill | 无法复用且易泄密 | 抽象为门禁/流程 |
| 只写「要做 X」 | 不知何时不做 | 补决策树与反模式理由 |
| 用控制台判中文 | 代码页误导 | conda 写入 + 文件验证 |
| 忘记 manifest | 项目安装不到 | 增删必改 |
| alwaysApply 塞长文 | 抢上下文 | 长内容进 skill |

## 12. 相关

- `privacy-github` / `field-validation-method` / `sync-cursor-to-project` / `work-reporting`
