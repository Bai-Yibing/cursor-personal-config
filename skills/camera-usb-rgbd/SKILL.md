---
name: camera-usb-rgbd
description: >-
  USB RGB-D, UVC, and side-by-side stereo camera methodology: bandwidth,
  zero-callback diagnosis, same-frame sync vs preview asymmetry, offline
  stereo calibration gates, and static CameraInfo publishing. Use when frames
  stop, callbacks are zero, USB saturates, stereo looks desynced, calibration
  RMS is high, or CameraInfo/stamp questions arise on remote Linux hosts.
---

# USB 相机 / RGB-D / 双目 UVC 诊断方法论

原则：**带宽与格式先于应用调参；同步先分清硬件同帧 vs 预览架构；标定先看姿态多样性与 RMS，不看 quality 旗标 alone。**  
不记录可识别私有硬件的序列号。

## 1. 问题定义

USB/UVC RGB-D 或双目模组在远端 Linux 上出现：零回调、丢帧、单流可用多流崩、控制面与协商流不一致、网页左右「不同步」、保存卡死、立体标定假收敛。根因常在物理层、协商层、预览架构或标定约束不足，而非业务调参。

## 2. 不变量 / 第一性原理

- **带宽硬上限**：USB2 无法可靠承载多路高分辨率 RGB+depth。
- **控制面 ≠ 数据面**：驱动声明能力 ≠ pipeline 已协商成功的 format/fps/size。
- **编码载体需解码链路**：压缩格式若中间件不支持会「能枚举但零回调」。
- **单进程独占**：设备节点被其他进程打开则新开流失败。
- **同帧 SBS ≠ 双路独立预览**：Side-by-Side 单流硬件同帧；双路各自 MJPEG 解码刷新可造成观感差帧。
- **CameraInfo 每帧发 ≠ 每帧重估内外参**：定焦 UVC 通常离线标定 + 同戳重复发静态 K/D/R/P。
- **标定约束不足会互补偿**：姿态单一时内参与外参对冲；基线接近机械值只说明尺度大致合理，不证明 RMS 可用。

## 3. 架构/选型决策树

| 链路/环境 | 风险 | 应对 |
|----------|------|------|
| USB2 | 带宽饱和 | 降分辨率/帧率、减少并发流 |
| USB3 经 hub | 降速、共享 | 直连、换线、核对协商速率 |
| 编码主码流 | 解码缺失 | 确认 fourcc 与解码器链 |
| 多流同开 | 竞争带宽 | 单流稳定后逐流增加 |
| 控制面 Meta | 期望与实际脱节 | 分开验证两层 |
| SBS 单流双目 | 误判「硬件不同步」 | 先确认是否同帧拼图；预览用同帧出口 |
| 双独立 MJPEG 预览 | 观感左右差帧 | 不据此断硬件不同步；落盘 left/right 同源即可 |
| 要「动态内外参」 | 固件无 OTP/厂标流 | 离线标定 + 每帧静态 CameraInfo |
| 联合标定 RMS 高 | 姿态/距离单一 | 多距离多倾角完整入画再解；当前 YAML 仅冒烟 |

## 4. 标准操作流程 SOP

1. 记录设备类型、USB 协商速率、线缆/hub 拓扑（不记序列号）。
2. 枚举每路 stream 的 format、size、fps、编码；双目注明 SBS 或左右独立节点。
3. **自底向上**：内核/UVC → 中间件 → 框架/ROS，逐层计回调。
4. **单流先通**，再逐个增加流；记录 Hz 与丢帧率。
5. 换直连口、换线、去 hub 做控制变量对比。
6. 确认无第二进程独占设备。
7. 预览与采集分离负载：预览只留小图；保存异步写盘，避免每帧全分辨率拷贝堵请求线程。
8. 立体标定：采集多姿态 → 有界/无界联合解 → 看 RMS、基线、重投影分布 → 再挂深度/建图。
9. ROS：每帧发布对齐 stamp 的静态 CameraInfo；不做单帧在线自标定。

## 5. 度量与门禁

| 检查项 | 通过标准 |
|--------|----------|
| USB 速率 | 高带宽任务跑在 USB3 直连口 |
| 协商一致 | 枚举格式 = 实际打开格式 |
| 单流稳定 | 回调 Hz 达预期、无零回调 |
| 多流 | 每增一流均量带宽余量 |
| 双目「同步」 | SBS 同帧已确认；或左右 stamp 对齐策略已文档化 |
| 标定可用 | 姿态多样 + RMS 达任务阈值；**不只** quality_ok / 基线接近 |
| CameraInfo | stamp/frame_id 与图像对齐；矩阵可静态 |
| 保存/预览 | 保存不拖垮采集线程；无长时间锁死 |
| 隐私 | 文档只用 `<perception_host>` 与通用参数 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 能枚举、零回调 | format 失败、无解码路径 | 最小管线单独测 |
| 单流 OK、多流崩 | 带宽饱和 | 逐流增加 |
| 帧率折半 | 降速口线 | `lsusb -t` / `dmesg` |
| Meta 与实际不符 | 控制面误导 | 分开对照 |
| 间歇丢帧 / USB -71 | 热、电源、线材、hub | 直连 + 长时间 Hz + dmesg |
| 网页左右差几帧 | 双路独立解码刷新 | 改同帧拼图预览；查是否 SBS |
| 要动态 K 才发 CameraInfo | 误解 ROS 惯例 | 静态标定 + 每帧 stamp |
| 标定 quality_ok 但深度漂 | RMS 高、姿态不足 | 看 RMS/姿态分布；重采 |
| 点保存卡死 | 全分辨率拷贝 + 同步 JPEG + 锁 | 降预览分辨率、异步写、减锁竞争 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 先调业务参数 | 底层未通 | 先单流回调 |
| 相信驱动声明分辨率 | 未协商成功 | 实测打开的格式 |
| USB2 硬开多路高清 | 物理不可能 | 降载或换 USB3 |
| 多流同时排查 | 无法归因 | 单流→多流逐步 |
| 网页差帧 = 硬件不同步 | 常是预览架构 | 先确认 SBS/同帧出口 |
| quality_ok + 基线对 = 标定真值 | RMS 可仍数十 px | 姿态多样 + RMS 门禁 |
| 每帧重估内外参 | UVC 无可靠在线真值 | 离线标定 + 静态 CameraInfo |
| 预览每帧全分辨率拷贝 | CPU/锁拖垮采集 | 小图预览 + 异步保存 |

## 8. 交付/复盘检查清单

- [ ] USB 速率与拓扑已记录
- [ ] 单流回调稳定；所需多流各自达标
- [ ] 控制面与 UVC 载体已分开验证
- [ ] 双目同步结论有证据（SBS 或 stamp 策略）
- [ ] 标定报告含姿态多样性说明与 RMS；冒烟 YAML 已标明不可当真值（若适用）
- [ ] CameraInfo 与图像 stamp 对齐
- [ ] 预览/保存负载分离，采集线程不被保存阻塞

```bash
ssh <perception_host> 'lsusb; dmesg | tail -50'
ssh <perception_host> 'v4l2-ctl --list-devices; v4l2-ctl --list-formats-ext'
```

## 9. 相关 skills

- 建图同步：`visual-slam-mapping`
- 语义占据：`semantic-occupancy-fusion`
- 实验方法：`field-validation-method`
- 远端执行：`remote-ssh-dev`
