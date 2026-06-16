---
name: general-software-dev
description: >-
  General software development on remote Linux servers via SSH. Use when
  writing, debugging, or reviewing code that runs on remote hosts, APIs,
  scripts, tests, or when the user works primarily through Cursor Remote-SSH
  or ssh terminal sessions.
---

# 通用软件开发（远程 SSH）

默认代码在**远程 Linux** 运行；本机 Windows 为 Cursor 客户端。

## 开始任务

1. 确认**执行主机**（S100 / 云服务器等）与仓库远端路径。
2. 读相关文件与调用链（Remote-SSH 工作区直接读；否则 ssh 上查看）。
3. 需要运行时证据 → 在**部署机**上复现，不单靠本机推断。

## 实现

- 最小正确 diff；改完确认已同步到将运行的环境（git push/pull 或已在远端工作区）。
- 构建与测试在远端：`ssh Host 'cd repo && make/test'` 或 Remote-SSH 终端。
- API/配置变更：同步远端 launch/环境变量。

## 验证

```bash
# 工作区在 Windows 时
ssh <Host> 'cd <repo> && <test command>'

# 已在 Remote-SSH 工作区
<test command>
```

- 报告：改了什么、**哪台机器**验证、如何复现。

## 输出

- 复杂逻辑用步骤说明；命令注明 `ssh Host` 前缀（若本机执行）。
- 路径对照：本机 `D:\...` vs 远端 `/root/...`（若两边都有）。
