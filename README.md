# Cursor 个人配置（Rules + Skills）

本仓库可公开发布：不绑定任何主机、IP、用户名或项目路径。

## 架构

```text
本机 Windows: $env:USERPROFILE\.cursor\rules|skills
        → publish-cursor-config.ps1
Linux / Remote-SSH: ~/.cursor-personal-config/rules|skills   ← 推荐直接改这里
        → git push → GitHub（本仓库）
        → git pull
任意项目: install-to-project.sh|ps1 → <project_root>/.cursor/
        （只覆盖 sync-manifest 列出的文件；不删项目自有配置）
```

**注意**：Remote-SSH 下改的 `<project_root>/.cursor/...` 是安装副本。要进 GitHub，须写回 `~/.cursor-personal-config` 再 push。详见 skill `sync-cursor-to-project`。

## 安装

```powershell
# Windows：从本机 USERPROFILE\.cursor 发布到本仓后 push
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\publish-cursor-config.ps1"
cd $env:USERPROFILE\.cursor\cursor-personal-config
git push
```

```bash
# Linux：每台主机一次
git clone https://github.com/Bai-Yibing/cursor-personal-config.git ~/.cursor-personal-config

# 每个项目一次（或改配置后重装）
~/.cursor-personal-config/scripts/install-to-project.sh /path/to/your/repo
```

## 远端改完个人配置后推送

```bash
git -C ~/.cursor-personal-config pull --rebase
# 编辑 ~/.cursor-personal-config/rules|skills ，或从项目副本按 manifest 拷回
cd ~/.cursor-personal-config
# 隐私自检后：
git add -A && git commit -m "Update skills/rules" && git push
~/.cursor-personal-config/scripts/install-to-project.sh <project_root>
```

不要把 `vln-*`、`project-overview`、工作存档/日报正文拷进本仓。

## 隐私

- 仅使用 `<Host>`、`<project_root>`、`<maps_output>`、`<ptq_workspace>`、`<perception_host>`、`<robot_host>`、`<ptq_host>` 等占位符。
- 不提交 IP、密码、token、串号、RTSP 凭据、真实日志或实机数据。
- 发布前运行隐私检索，并用角色化主机名替换环境细节。

## 方法论 Skills（通用工程 SOP）

领域 skills 是可复用方法论手册：决策树、门禁、反模式与现场验证流程，而非单一产品配方。

| Skill | 方法论聚焦 |
|-------|------------|
| `field-validation-method` | O→H→V→C、单变量、验收指标、run_meta |
| `visual-slam-mapping` | 传感拓扑、前后端分离、位姿/占据分表验收、失锁政策 |
| `semantic-occupancy-fusion` | 几何/语义解耦、footprint、扩边 remap、地图 diff |
| `horizon-bpu-ptq` | 边缘 NPU/BPU PTQ、CPU fallback 门禁、板端指标 |
| `nav-safety-collision` | 分层防护、时间线复盘、unknown 保守 |
| `camera-usb-rgbd` | USB 带宽、SBS 同帧、静态 CameraInfo、标定门禁 |
| `device-ipc-protocol` | 设备客户端状态机、mock E2E、传输/schema 分离 |
| `ros2-robotics` | ROS2 远端工程习惯与检查清单 |
| `cursor-config-remote-sync` | 远端/板端改配置后反向同步、bundle 桥接、各端 install |
| `author-cursor-config` | 撰写/迭代 skills 与 rules |
| `remote-ssh-dev` | 角色化 SSH 开发与材料收集 |
| `sync-cursor-to-project` | 正向安装与反向写回真源 |

## 同步清单

根目录 `sync-manifest.json` 决定安装到项目的 rules 和 skills；项目自有配置不会被删除。远端汇报暂存目录为 `<project_root>/.cursor/工作存档/`（工作正文不进本仓）。
