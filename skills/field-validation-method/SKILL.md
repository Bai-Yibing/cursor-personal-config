---
name: field-validation-method
description: >-
  Cross-cutting field validation and experimental methodology (O-H-V-C loop,
  control variables, acceptance metrics, evidence alignment). Use when designing
  tests, interpreting field results, writing run reports, or deciding whether
  a smoke test or long run is warranted before claiming success.
---

# 实验验证与现场方法论

适用于建图、导航、量化、相机、协议等所有现场工作。核心是把「观测」与「结论」分开，避免把算力成功当成任务成功。

## 1. 问题定义

本 skill 解决的是：**如何在复杂系统中做可复现、可审计的现场验证**。典型失败是混淆观测与假设、同时改多个变量、用虚荣指标替代验收指标。

## 2. 不变量 / 第一性原理

- **因果可审计**：每次改动必须能追溯到单一变量与对照组。
- **虚荣 ≠ 验收**：编译通过、文件存在、覆盖率上升不等于任务达标。
- **时间对齐**：多源证据（日志、视频、传感器、地图）必须同一时间窗口解读。
- **风险对称**：安全相关验证先短冒烟、可回滚，再长跑。

## 3. O→H→V→C 决策树

| 阶段 | 问题 | 产出 |
|------|------|------|
| **O 观测** | 现象是什么？发生在哪一刻？ | 带时间戳的原始证据 |
| **H 假设** | 最可能的单一原因是什么？ | 可否证的假设句 |
| **V 验证** | 如何只改一个变量来证伪？ | 对照试验 / A-B 设计 |
| **C 结论** | 支持或否定？置信度？ | 带标签的结论 + 下一步 |

若无法写出可否证假设，停在 O，继续收集证据。

## 4. 标准操作流程 SOP

1. **写 session_meta / run_meta**（见本文模板）。
2. **短冒烟**：最小可复现路径，验证链路通、无致命错误。
3. **打 rollback 标签**：git tag / 产物版本号 / 配置快照。
4. **单变量试验**：其余环境锁定。
5. **长跑前门禁**：冒烟指标全部通过才扩大时长或场景。
6. **时间轴对齐**：把日志、视频、传感器、地图快照放在同一时间线上复盘。
7. **记录结论置信度**：确证 / 强推断 / 弱推断 / 待证。

## 5. 度量与门禁

| 类型 | 示例（虚荣） | 示例（验收） |
|------|----------------|----------------|
| 建图 | known% 高 | 闭环后拓扑一致、跟踪丢失率低、**位姿 KPI 与占据 KPI 分列** |
| 语义融合 | 日志 cells / glass hits | 对齐网格后的 map diff、实体块状、VO 不退化 |
| 量化 | 编译成功 / UI 进度 100% / 单点校准 cosine | 加速器门禁 + 板端延迟 + **多指标**任务达标；校准域对齐部署 |
| 导航 | 覆盖率上升 | 无碰撞、unknown 保守通行 |
| 相机 | 能枚举设备 | 回调 Hz 稳定、无零回调 |
| 双目标定 | quality_ok、基线接近机械值 | 姿态多样 + RMS 达阈值；YAML 可否用于深度真值 |

**通过标准**：每次试验必须明确写出至少一个验收指标与阈值；未定义阈值的试验不得用于发布决策。量化类另要求：校准分布与部署域一致，禁止用错域 held-out「刷」单一余弦。

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 「感觉好了」但无数据 | 确证者偏误 | 回放原始日志，找对照指标 |
| 两次结果矛盾 | 环境变量未记录 | 补全 run_meta，重复短冒烟 |
| 修了 A 却影响 B | 多变量同时改动 | 回滚后单独验证 A |
| 长跑才暴露问题 | 未做短冒烟 | 先用最小场景复现 |
| 门禁过但任务崩 | 校准/评测域错位 | 对照部署分布重采校准与 held-out |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 「进度 100% 就算完成」 | UI 不等于产物就绪 | 检查落盘文件与结尾日志 |
| 同时改多个参数 | 无法归因 | 每轮只改一项，留对照组 |
| 用覆盖率代替拓扑正确 | 开环投影可造假高覆盖 | 看 loops、path/span、目视一致性 |
| 长跑前不做冒烟 | 代价高、难回滚 | 先短距离、低速、可急停场景 |
| 单点校准余弦当验收 | 域错时仍可能「好看」 | 多指标 + held-out + 板端任务 |

## 8. session_meta / run_meta 模板

```yaml
session_meta:
  id: "<session_id>"
  host_role: "<perception_host>|<robot_host>|<ptq_host>"
  project: "<project_root>"
  git_ref: "<tag_or_commit>"
  hypothesis: "<one falsifiable sentence>"
  changed_variable: "<exactly one>"
  control_baseline: "<run_id or config snapshot>"
  smoke_passed: true|false
  rollback_tag: "<tag>"
run_meta:
  start_ts: "<ISO8601>"
  end_ts: "<ISO8601>"
  vanity_metrics: {}
  acceptance_metrics: {}
  evidence_paths: ["<maps_output>/<session>/...", "..."]
  conclusion: "<supported|refuted|inconclusive>"
  confidence: "<verified|strong|weak|pending>"
  next_step: "<one action>"
```

## 9. 相关 skills

- 建图验收指标：`visual-slam-mapping`
- 语义融合验收：`semantic-occupancy-fusion`
- 边缘部署门禁：`horizon-bpu-ptq`
- 撞物时间线复盘：`nav-safety-collision`
- 相机链路验证：`camera-usb-rgbd`
- 协议 mock 验证：`device-ipc-protocol`
- 远端取证：`remote-ssh-dev`
