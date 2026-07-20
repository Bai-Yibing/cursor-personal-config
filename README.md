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

## 方法论 Skills（通用工程 SOP）

本仓库的领域 skills 是**可复用的方法论手册**：决策树、门禁、反模式与现场验证流程，而非单一产品配方。具体栈仅作短示例。

| Skill | 方法论聚焦 |
|-------|------------|
| `field-validation-method` | O→H→V→C、单变量、验收指标、run_meta |
| `visual-slam-mapping` | 传感拓扑、前后端分离、闭环验收、失锁政策 |
| `semantic-occupancy-fusion` | 几何/语义解耦、安全不对称、地图 diff 验收 |
| `horizon-bpu-ptq` | 边缘 NPU/BPU PTQ、CPU fallback 门禁、拆图与板端指标 |
| `nav-safety-collision` | 分层防护、时间线复盘、unknown 保守 |
| `camera-usb-rgbd` | 带宽优先、控制面 vs 协商流、零回调自底向上 |
| `device-ipc-protocol` | 设备客户端状态机、mock E2E、传输/schema/域分离 |
| `ros2-robotics` | ROS2 远端工程习惯与检查清单 |
| `author-cursor-config` | 如何撰写/迭代 skills 与 rules（抽象、隐私、骨架、发布） |
| `remote-ssh-dev` | 角色化 SSH 开发与材料收集 |

## 同步清单

`scripts/sync-manifest.json` 决定安装到项目的 rules 和 skills；项目自有配置不会被删除。远端暂存目录为 `<project_root>/.cursor/工作存档/`。
