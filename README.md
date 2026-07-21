# Cursor 个人配置（Rules + Skills）

本仓库可公开发布：不绑定任何主机、IP、用户名或项目路径。

## 架构

```text
编辑真源（推荐）
  Linux: ~/.cursor-personal-config
  Windows: $env:USERPROFILE\.cursor\rules|skills → publish-cursor-config.ps1
        → git push → GitHub（本仓）
        → install-to-project.sh|ps1 → <project_root>/.cursor/
```

项目 `.cursor` 是安装副本。详见 skill `cursor-config-sync`（含反向同步与 bundle 桥接）。

## 隐私

仅使用占位符；不提交 IP/密码/token/串号/实机原始数据。见 `privacy-github`。

## Skills（精简后）

| Skill | 用途 |
|-------|------|
| `cursor-config-sync` | 安装、正/反向同步、bundle 桥接 |
| `author-cursor-config` | 如何撰写 skills/rules |
| `remote-ssh-dev` | 远端 SSH 开发与取材 |
| `field-validation-method` | O→H→V→C、验收指标 |
| `visual-slam-mapping` / `semantic-occupancy-fusion` / `horizon-bpu-ptq` / `nav-safety-collision` / `camera-usb-rgbd` / `device-ipc-protocol` | 领域方法论 |
| `ros2-robotics` | ROS2 远端工程 |
| `daily-report` / `daily-knowledge-base` / `weekly-*` / `work-reporting-pipeline` | 汇报流水线 |

## 同步清单

根目录 `sync-manifest.json` 决定安装到项目的文件；不删项目自有配置。
