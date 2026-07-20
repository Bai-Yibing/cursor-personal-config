---
name: camera-usb-rgbd
description: >-
  USB RGB-D / UVC camera bandwidth and zero-callback diagnosis. Use when frames
  stop, callbacks are zero, USB2 saturation, H264 4K UVC carrier traps, or Meta
  vs UVC resolution mismatches on remote Linux hosts.
---

# USB 相机与 RGBD 诊断

原则：带宽与格式先于软件调参。不记录可识别私有硬件的厂商序列号；示例用通用分辨率/格式。

## 1. 带宽原则

| 链路 | 风险 | 应对 |
|------|------|------|
| USB2 | 高分辨率 RGB+depth 超带宽 | 降分辨率/帧率、减少并发流 |
| USB3 | hub/线缆/共享根集线器仍可降速 | 直连端口、核对实际协商速率 |
| UVC 视频 | 格式、主码流可能不匹配消费端 | 先枚举 format/fps/size 再选流 |

**要求**：高分辨率 RGB-D 优先 USB3；USB2 上硬开多路高分辨率几乎必然丢帧或零回调。

## 2. Meta 期望 vs UVC 载体（H264 4K 陷阱）

不要把控制面「Meta / 期望分辨率」与 UVC 实际视频载体混为一谈。

- H264 4K 可降低总线带宽，但若解码器、GStreamer/ROS 输入或消费端不支持，会出现「能枚举但零回调」。
- 驱动宣称的能力 != 当前 pipeline 已协商成功的 format。
- 先确认实际打开的 fourcc / size / fps，再对比应用期望的 RGB/depth 布局。

## 3. 零回调诊断顺序

1. 记录设备类型、USB 协商速率、线缆/hub 拓扑（**不记序列号**）。
2. 单独验证每个 stream 的 format、size、fps 与编码。
3. 自底向上：内核/UVC -> 中间件 -> ROS，逐层测回调计数。
4. 一次只启用一路，再逐个增加；保留回调计数与丢帧率。
5. 换直连 USB3 口、换线、去掉 hub，做控制变量对比。
6. 确认没有第二进程独占设备节点。

## 4. 验收要点

- [ ] 实际 USB 速率符合预期（USB3 任务跑在 USB3 口）
- [ ] 枚举格式与打开格式一致；无「Meta 4K / 实际失败回退」 silently
- [ ] 单流稳定后再开多流；记录回调 Hz
- [ ] 文档只用 `<perception_host>` 与通用参数，无端点/串号

相关：建图传感器同步见 `visual-slam-mapping`；远端执行见 `remote-ssh-dev`。

## 5. 常见失败模式

| 现象 | 首查 |
|------|------|
| 能枚举、零回调 | format 协商失败、H264 无解码路径、设备被占 |
| 单流可用、多流崩 | USB2 带宽 / 共享 hub |
| 帧率折半 | 协商速率不符、线缆/口降速 |
| Meta 分辨率与实际不一致 | 分开控制面与 UVC 载体核对 |

## 6. 最小复现命令（示例）

```bash
ssh <perception_host> 'lsusb; dmesg | tail -50'
ssh <perception_host> 'v4l2-ctl --list-devices; v4l2-ctl --list-formats-ext'
# open one stream only, count callbacks, then add streams one by one
```

不在日志中粘贴厂商 SerialNo。
