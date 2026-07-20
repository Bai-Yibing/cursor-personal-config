---
name: device-ipc-protocol
description: >-
  Edge device IPC and cloud platform protocol integration methodology. Use when
  designing device-as-client state machines, mock end-to-end tests before real
  platforms, validating transport vs schema vs domain gaps, multipart HTTP
  contracts, or keeping secrets out of public repositories.
---

# 设备 IPC 与平台协议方法论

示例仅用 `<platform_host>`、`<device_id_placeholder>` 等占位符。**禁止**真实端点、序列号、token、密码写入公开配置。

## 1. 问题定义

边缘设备与云平台的连接、注册、指令下发、数据上传与状态同步。失败表现：能连通但业务错、断线后状态混乱、multipart 随机失败、或 enrollment 与实时流域差导致识别漂移。

## 2. 不变量 / 第一性原理

- **设备为客户端**：主动连接、心跳、重连退避由设备侧状态机管理。
- **传输 ≠ 协议 ≠ 业务域**：网络可达、schema 正确、任务达标须分开验证。
- **秘密与端点外置**：真实 URL/凭据只能进环境变量或私密配置。
- **幂等与确认**：指令、上传、注册需可重试且可关联请求 id。

## 3. 架构/选型决策树

| 阶段 | 做什么 | 不做什么 |
|------|--------|--------|
| 设计 | 画状态机 + 消息生命周期 | 直接粘贴生产 URL 到仓库 |
| mock E2E | 全流程含断线重连 | 把「能 ping」当成协议通过 |
| 真平台 | 只替换连接参数 | 改业务状态机 |
| 域验证 | enrollment vs live 分列指标 | 混用两种样本宣布达标 |

建议消息流：connect/hello → capability → enroll/config → command/ack/result → heartbeat → graceful close。

## 4. 标准操作流程 SOP

1. 定义 schema 版本与错误码表。
2. 搭 mock server，覆盖注册、配置、指令、回执、大包上传、断线重连。
3. 为每种消息写超时、幂等键与契约测试。
4. mock 全绿后接真平台（秘密配置注入端点）。
5. 分开验证传输层、schema 层、业务域（如 enrollment vs live）。
6. 公开文档与 rules/skills 脱敏复查。

## 5. 度量与门禁

| 检查项 | 通过标准 |
|--------|----------|
| mock E2E | 全用例绿，含重连 |
| schema 协商 | 版本不匹配时可拒绝或降级 |
| multipart | boundary/MIME/size 契约测试通过 |
| 真平台 | 仅私密配置接入，无端点泄露 |
| 域指标 | enrollment 与 live 分列达标 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 连上但指令无效 | field 名或版本不一致 | mock 契约测试 |
| 上传随机失败 | boundary/超时 | 独立大包测试 |
| 重连后状态错 | 缓冲未刷新 | 模拟断线用例 |
| 识别漂移 | enrollment/live 域差 | 分列 A/B 样本 |
| 日志泄密 | 硬编码凭据 | 隐私 grep |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 直接真接调试 | 无法区分网络与协议 | 先 mock E2E |
| 手拼 multipart | boundary 错误 | 用库生成 Content-Type |
| 连通=达标 | 域差未验证 | 分列任务指标 |
| 把 token 写进仓库 | 泄露风险 | 环境变量 |

## 8. 交付/复盘检查清单

- [ ] mock E2E 全绿（含重连与超时）
- [ ] 契约测试与 schema 版本协商
- [ ] 真平台仅私密配置
- [ ] enrollment/live 指标分列
- [ ] 公开文档无 IP/串号/凭据

## 9. 相关 skills

- 相机输入质量：`camera-usb-rgbd`
- 实验与置信度：`field-validation-method`
- 远端部署：`remote-ssh-dev`
