---
name: device-ipc-protocol
description: >-
  Device-side IPC and platform protocol (WebSocket client device, mock E2E,
  multipart HTTP, enrollment vs live camera domain gap). Use when integrating
  edge devices with a cloud/platform API before real endpoints are available.
---

# 设备 IPC 与平台协议

示例仅用 `<platform_host>`、`<device_id_placeholder>` 等占位符。**禁止**真实端点、SerialNo、token、密码写入公开配置。

## 1. 连接模型

设备通常作为 **WebSocket 客户端**主动连接平台。设计时明确：

- 重连退避与上线身份
- 心跳与超时
- 协议/schema 版本
- 消息确认与离线缓冲
- 错误码与可观测日志（脱敏）

## 2. 先 mock，后真接

1. 用 mock server 跑完整 E2E：注册、配置下发、指令、回执、断线重连。
2. 对每种消息记录 schema、序列、超时与幂等关联。
3. mock 通过后再接真实平台；把「网络可达」与「协议正确」分开验证。
4. 真接时用环境变量/私密配置注入端点，不写进 rules/skills。

## 3. HTTP multipart 易错点

| 问题 | 检查 |
|------|------|
| boundary 缺失或不匹配 | 让客户端库生成 Content-Type，勿手工拼接 |
| field 名不一致 | 以协议 schema 为准，做契约测试 |
| 文件类型/长度错误 | 在 mock 中校验 MIME、size、返回码 |
| 大包超时 | 独立测上传超时与重试，避免与业务 ACK 混淆 |

## 4. 域差异：enrollment vs 实时相机

用户录入照片与实时相机帧在光照、姿态、压缩与镜头上常有域差，导致识别漂移。

- 分开记录 enrollment 质量与 live 质量指标。
- 用可控样本做 A/B，不把「平台可连通」当成「识别已达标」。
- 文档与日志不写真实人脸图路径或设备串号。

## 5. 验收清单

- [ ] mock E2E 全绿（含断线重连）
- [ ] schema 版本协商通过
- [ ] multipart 契约测试通过
- [ ] 真平台仅通过私密配置接入；公开文档无端点/SerialNo
- [ ] enrollment / live 指标分列

相关：远端部署见 `remote-ssh-dev`；相机输入见 `camera-usb-rgbd`。

## 6. 消息生命周期（建议）

1. connect / hello / capability negotiate
2. enroll / config pull
3. command -> ack -> result
4. heartbeat; offline buffer flush on reconnect
5. graceful close / forced reconnect

每一步都要有 mock 用例与超时定义；真平台只替换连接参数，不改业务状态机。
