# Cursor 个人配置（Rules + Skills）

本仓库可公开发布：不绑定任何主机、IP、用户名或项目路径。真正配置在本机 `$env:USERPROFILE\.cursor\rules` 和 `$env:USERPROFILE\.cursor\skills`。

## 安装

```powershell
cd $env:USERPROFILE\.cursor\cursor-personal-config
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\scripts\publish-cursor-config.ps1"
```

```bash
git clone https://github.com/Bai-Yibing/cursor-personal-config.git ~/.cursor-personal-config
~/.cursor-personal-config/scripts/install-to-project.sh /path/to/your/repo
```

## 隐私

- 示例中仅使用 `<Host>`、`<project_root>`、`<maps_output>`、`<ptq_workspace>`、`<perception_host>`、`<robot_host>`、`<ptq_host>` 等占位符。
- 不提交 IP、密码、token、串号、RTSP 凭据、真实日志或实机数据。
- 发布前运行隐私检索，并用角色化主机名替换环境细节。

## 领域 Skills

| Skill | 用途 |
|-------|------|
| `visual-slam-mapping` | IR 双目手持建图、开环陷阱、闭环验收 |
| `semantic-occupancy-fusion` | 语义旁路、玻璃启发式、地图 diff |
| `horizon-bpu-ptq` | S600 多 HBM、FoundationStereo、InternNav、YOLOE |
| `nav-safety-collision` | depth-scan 空隙、costmap、防撞分层 |
| `camera-usb-rgbd` | USB 带宽、UVC/H264、零回调 |
| `device-ipc-protocol` | WebSocket 设备客户端、mock E2E、multipart |
| `ros2-robotics` | ROS2 话题、TF、QoS 与安全调试 |
| `remote-ssh-dev` | 角色化 SSH 开发与材料收集 |

## 同步清单

`scripts/sync-manifest.json` 决定安装到项目的 rules 和 skills；项目自有配置不会被删除。远程暂存目录为 `<project_root>/.cursor/工作存档/`。
