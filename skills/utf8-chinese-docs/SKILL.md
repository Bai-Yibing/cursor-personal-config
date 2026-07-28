---
name: utf8-chinese-docs
description: >-
  Prevent and repair corrupted Chinese documentation on Windows and mixed
  toolchains (UTF-8 vs GBK, Write/PowerShell/Python escapes). Use when creating
  or editing Chinese .md/.txt/skills/rules/日报/经验总结, seeing
  mojibake, U+FFFD, four-question-mark runs, missing letters after near_/roi_,
  or before delivering Chinese docs.
---

# 中文文档 UTF-8 防写坏

## 1. 问题定义

在 Windows + Agent 工具链上，含中文的 md/txt **反复**被写成：

- 全文四连问号或乱码
- UTF-8 被当 GBK 读、或 GBK 字节当 UTF-8 解
- 标识符被吃掉（`near_a` → 换行 + `ear_a`）
- 控制台与文件真实状态不一致

本 skill 给出：**何时用哪条写入通道、如何验收、常见故障如何否证**。

## 2. 不变量

1. **真源是文件字节**，不是终端显示。
2. 交付编码：**UTF-8 无 BOM**。
3. **写完必校验**；未校验 = 未完成。
4. 已有正确 UTF-8 文件：优先小范围替换，不做无谓整文件重写。

## 3. 决策树：怎么写

```text
要写/改含中文文档？
  ├─ 只改已有 UTF-8 文件的局部？
  │     → StrReplace / apply_patch（最稳）→ 校验
  ├─ 整文件新建或大段重写？
  │     ├─ Write 可用？ → Write → 立刻校验；失败则换通道
  │     ├─ Write 曾写坏 / 路径特殊？
  │     │     → 仅 ASCII 的 .py + \uXXXX
  │     │     → 或 UTF-8 base64 + write_utf8_text.py
  │     └─ 禁止：PowerShell Set-Content/Out-File/here-string 写中文
  └─ 批量？ → 先单篇打通校验再循环
```

## 4. SOP

### 4.1 推荐写入通道

| 优先级 | 通道 | 适用 |
|--------|------|------|
| 1 | StrReplace / patch | 改已有正确文件 |
| 2 | 编辑器 Write | 短文；**写后必校验** |
| 3 | scripts/write_utf8_text.py --base64 | 命令行保持 ASCII |
| 4 | 仅含 \uXXXX 的生成 .py | Write 不可信时 |

### 4.2 校验（强制）

```bash
python skills/utf8-chinese-docs/scripts/check_utf8_cjk.py path/to/file.md
python skills/utf8-chinese-docs/scripts/check_utf8_cjk.py path/to/dir --glob "*.md"
```

退出码 0 才可交付。检查：UTF-8可解、无 U+FFFD、无四连问号、无 UTF-16 BOM；应含中文则要求检出 CJK。

### 4.3 Python 字符串陷阱

在非 raw 字符串中，`\near_a` 会变成换行+`ear_a`；`\root` / `\results` 中的 `\r` 会变成回车。
标识符写 `'near_a'`；中文用 `\uXXXX` 或 base64。

### 4.4 PowerShell / cmd

禁止 `Set-Content` / `Out-File` / here-string 写中文 md。PS 只调 `python ...`。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| 控制台看起来像中文 | 文件 UTF-8 decode 成功 |
| 「我用了 UTF-8 参数」 | check_utf8_cjk.py 退出码 0 |
| 只抽查一篇 | 本次改动的每一篇都过检 |

## 6. 故障分类

| 症状 | 原因 | 修复 |
|------|------|------|
| 全文四连问号 | GBK/错误管道；Write 失败 | \uXXXX / base64 重写 |
| U+FFFD | 错误解码 | 找源或重生 |
| near_a→换行+ear_a | Python \n 转义 | 搜行首 ear_/oi_ 并修复 |
| 控制台乱、编辑器正常 | 代码页 | 以校验脚本为准 |

## 7. 反模式

| 做法 | 为何失败 |
|------|----------|
| 写完靠看终端 | 代码页误导 |
| PS here-string 写中文 | GBK → `?` |
| 普通字符串拼 \near_ | 静默破坏标识符 |
| 未校验就交付 | 坏文进真源 |

## 8. 交付清单

- [ ] 写入通道在决策树内
- [ ] check_utf8_cjk.py 退出码 0
- [ ] 无四连问号 / U+FFFD；标题可读
- [ ] 无 ear_/oi_ 转义残片
- [ ] 若改 skills/rules：按 author-cursor-config 发布

## 9. 相关

- Rule：utf8-chinese-docs（alwaysApply）
- author-cursor-config / daily-report / privacy-github
