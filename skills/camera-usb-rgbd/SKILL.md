---
name: camera-usb-rgbd
description: >-
  USB RGB-D and UVC camera bandwidth and zero-callback diagnosis methodology.
  Use when frames stop, callbacks are zero, USB bandwidth saturates, encoded
  carrier formats mismatch consumer pipelines, or control-plane capability
  differs from negotiated streams on remote Linux hosts.
---

# USB 相机与 RGB-D 诊断方法论

原则：**带宽与格式先于应用调参**。不记录可识别私有硬件的序列号。

## 1. 问题定义

USB/UVC RGB-D 相机在远端 Linux 上出现零回调、丢帧、单流可用多流崩溃、或控制面分辨率与实际流不一致。根因常在物理层与协商层，而非业务逻辑。

## 2. 不变量 / 第一性原理

- **带宽硬上限**：USB2 无法可靠承载多路高分辨率 RGB+depth。
- **控制面 ≠ 数据面**：驱动声明能力 ≠ pipeline 已协商成功的 format/fps/size。
- **编码载体需解码链路**：压缩格式若中间件不支持会「能枚举但零回调」。
- **单进程独占**：设备节点被其他进程打开则新开流失败。

## 3. 架构/选型决策树

| 链路/环境 | 风险 | 应对 |
|----------|------|------|
| USB2 | 带宽饱和 | 降分辨率/帧率、减少并发流 |
| USB3 经 hub | 降速、共享 | 直连、换线、核对协商速率 |
| 编码主码流 | 解码缺失 | 确认 fourcc 与解码器链 |
| 多流同开 | 竞争带宽 | 单流稳定后逐流增加 |
| 控制面 Meta | 期望与实际脱节 | 分开验证两层 |

## 4. 标准操作流程 SOP

1. 记录设备类型、USB 协商速率、线缆/hub 拓扑（不记序列号）。
2. 枚举每路 stream 的 format、size、fps、编码。
3. **自底向上**：内核/UVC → 中间件 → 框架/ROS，逐层计回调。
4. **单流先通**，再逐个增加流；记录 Hz 与丢帧率。
5. 换直连口、换线、去 hub 做控制变量对比。
6. 确认无第二进程独占设备。
7. 通过后再接入上层应用。

## 5. 度量与门禁

| 检查项 | 通过标准 |
|--------|----------|
| USB 速率 | 高带宽任务跑在 USB3 直连口 |
| 协商一致 | 枚举格式 = 实际打开格式 |
| 单流稳定 | 回调 Hz 达预期、无零回调 |
| 多流 | 每增一流均量带宽余量 |
| 隐私 | 文档只用 `<perception_host>` 与通用参数 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 能枚举、零回调 | format 失败、无解码路径 | 最小管线单独测 |
| 单流 OK、多流崩 | 带宽饱和 | 逐流增加 |
| 帧率折半 | 降速口线 | lsusb -t / dmesg |
| Meta 与实际不符 | 控制面误导 | 分开对照 |
| 间歇丢帧 | 热、电源 | 长时间 Hz 监控 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 先调业务参数 | 底层未通 | 先单流回调 |
| 相信驱动声明分辨率 | 未协商成功 | 实测打开的格式 |
| USB2 硬开多路 4K | 物理不可能 | 降载或换 USB3 |
| 多流同时排查 | 无法归因 | 单流→多流逐步 |

## 8. 交付/复盘检查清单

- [ ] USB 速率与拓扑已记录
- [ ] 单流回调稳定
- [ ] 所需多流各自达标
- [ ] 控制面与 UVC 载体已分开验证

```bash
ssh <perception_host> 'lsusb; dmesg | tail -50'
ssh <perception_host> 'v4l2-ctl --list-devices; v4l2-ctl --list-formats-ext'
```

## 9. 相关 skills

- 建图同步：`visual-slam-mapping`
- 实验方法：`field-validation-method`
- 远端执行：`remote-ssh-dev`
