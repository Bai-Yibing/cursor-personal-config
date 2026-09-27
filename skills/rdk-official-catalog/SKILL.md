---
name: rdk-official-catalog
description: >-
  Maps D-Robotics official Agent Skills (rdk-skills hub, device, BSP, OE X5/S)
  onto personal field playbooks. Use when installing or citing vendor skills,
  choosing hb_mapper vs hb_compile, hrt_model_exec, Perfetto, TogetheROS,
  MIPI camera, or board diagnostics; when vendor defaults conflict with
  on-device quality, IOVA, or privacy rules.
---

# 地瓜官方 Skill 目录对照（个人仓）

地瓜（[D-Robotics](https://github.com/D-Robotics)）把板端诊断、量化编译、推理评测做成可安装 Agent Skills。本 skill **不镜像**那 90+ 份正文，只规定：何时去官方仓、何时以本仓现场门禁为准。

官方文档/技能内容多为 CC-BY-4.0；此处为摘要与冲突裁决，不是替代官方原文。

总入口：[D-Robotics/rdk-skills](https://github.com/D-Robotics/rdk-skills)。安装示例：`npx skills add d-robotics/rdk-skills`（交互勾选）。**不要**把官方包整仓拷进个人 `cursor-personal-config`。

## 1. 问题定义

官方 skill 解决的是：**厂商命令、路径、工具开关以文档为准，而不是模型记忆**。  
个人 skill 解决的是：**任务质量、IOVA、独占时延、隐私、远程角色主机**。

常见失败：把官方全链路默认当成产品配方；把 `hrt_model_exec` FPS 当成芯片能力；把官方「多模型同会话」写成可以两进程双持有；把板端 IP/密码写进公开仓。

## 2. 不变量

1. **冲突裁决**：现场硬门（`horizon-bpu-ptq` / `edge-accel-eval` / `edge-bpu-runtime-iova` / `privacy-github`）> 官方单步默认 > 官方全链路示例配方。同芯社区封装（BLLM/BCDL 类）再低一档：可对照、可试用，不能覆盖现场门；见 `community-edge-npu`。
2. **X 系列产物 `.bin`，S 系列产物 `.hbm`**。march：X5 `bayes-e`；S100 `nash-e`/`nash-m`；S600 `nash-p`。
3. **观察与动作分离**：诊断只读；改桌面/清缓存/升核/编译须单独确认。读不到的信号报 `null`/`false`，禁止编造。
4. **主机只用角色占位符**。官方 perf skill 常向用户要板端 IP——本仓禁止写入文档与 skill。
5. **官方 cosine≥0.99 / HMCT 自动混精度**是工具链探针，不是任务验收。
6. **官方 nash-p 全链路示例**可能默认 histogram、body fp16、去掉 Quantize+Dequantize。本仓默认仍是全加速器驻留 + 无证据不升位宽；示例配方须双路径，不得覆盖已过门交付。
7. **官方 UCP C++ 交付**不等于本仓板上验收。本仓以同 feed 任务指标 + 独占分段 `run()` 为准。
8. **高频资源监控**走板端 `hrt_ucp_monitor` / `hrut_ddr` / `hrt_model_exec`，不要用 gRPC `hbm_infer` 打满。

## 3. 仓与包（去哪读原文）

| 包 | 仓 | 何时打开 |
|----|----|----------|
| Hub 目录 | [rdk-skills](https://github.com/D-Robotics/rdk-skills) | 不知道官方有没有对应 skill |
| 板端设备 | [rdk-device-skills](https://github.com/D-Robotics/rdk-device-skills) | 健康快照、ION/CMA、相机、TROS、`hrt_model_exec` |
| OE S 系列 | [oe-skills-s](https://github.com/D-Robotics/oe-skills-s) | `hb_compile`、HBDK YAML、UCP、Perfetto、`hb_analyzer`、HMCT、Plugin QAT |
| OE X5 | [oe-skills-x5](https://github.com/D-Robotics/oe-skills-x5) | `hb_mapper` / `.bin`、X5 Python API |
| BSP | [bsp-skills](https://github.com/D-Robotics/bsp-skills) | 镜像/内核/deb；**不**覆盖刷机与本仓评测 |
| 文档写作 | [doc-skills](https://github.com/D-Robotics/doc-skills) | 手册体例；与本仓日报无关 |
| 知识模块 | [device-knowledge](https://github.com/D-Robotics/device-knowledge) | 板型规格溯源 |

S 系列工作区集成会铺 `.horizon/`；X5 铺 `.drobotics/`。这是**厂商工作区**，不是本仓真源。未用户要求不要 `setup.sh` 进业务仓。

## 4. 路由到本仓 skill

```text
用户要厂商命令/YAML/官方脚本？
  → 打开上表对应仓的 SKILL.md（只读引用）
用户要任务质量 / 看图 greedy / TTS CER / IOVA / 独占 tok/s？
  → 本仓领域 skill，官方数字只当线索
板卡是谁、烫、慢、内存、dmesg？
  → 官方 rdk-diagnostic / memory-audit / log-forensics（只读）
  → 改桌面/清缓存 → 官方 headless/audit 的 --apply 须用户确认
MIPI/USB 不出图？
  → 先官方 rdk-camera-setup（i2c / 官方 sample）
  → USB 带宽/UVC/双目标定仍走 camera-usb-rgbd
相机→BPU→显示哪一段断？
  → 官方 rdk-vision-pipeline 分段；时延仍走 edge-accel-eval
TogetheROS / hobot 节点？
  → 官方 rdk-tros-setup（/opt/tros）；Humble overlay 仍走 ros2-robotics，禁止两套叠 source
量化编译？
  → S：oe-skills-s（router → hbdk/hmct/plugin/ucp）
  → X5：oe-skills-x5（mapper）
  → 门禁仍走 horizon-bpu-ptq
板上 FPS？
  → 官方 hrt_model_exec / hb_analyzer / Perfetto 可采集
  → 报告口径仍走 edge-accel-eval（独占、分段、任务分列）
多 HBM / iova addr not equal？
  → 只走 edge-bpu-runtime-iova；官方「多模型 session」不能否证粘滞
启动砖 / Hash mismatch / SPL 循环 / A-B 槽 / overlayroot /boot？
  → 只走 embedded-ab-avb-boot
  → BSP 刷机、mmc write 仍须用户确认；禁止手改 AVB boot 内 DTB
```

## 5. 从官方抽来、已并入本仓的方法（摘要）

| 官方做法 | 并入位置 | 本仓修正 |
|----------|----------|----------|
| 诊断只读，动作另 skill | `remote-ssh-dev` / `field-validation-method` | 信号缺失写待验证，不编造 |
| 活测 DRAM/CMA/ION，理论不够 | `edge-accel-eval` / `edge-bpu-runtime-iova` | load 前预检堆，假 corrupted 当 IOVA |
| `hrt_model_exec perf`、thread/core 扫描 | `edge-accel-eval` | 扫描≠独占芯片时延；绑核须=编译核 |
| `hb_analyzer` / Perfetto 找空隙 | `edge-accel-eval` / `edge-accel-improve` L1–L2 | 利用率低先查带宽/段间隙 |
| YAML 确认后再编译 | `horizon-bpu-ptq` | 双路径；不覆盖过门包 |
| QAT 按 export/convert/compile 分段 | `horizon-bpu-ptq` | 与 host sim / convert 漏斗对齐 |
| 无证据不升混精度 | `horizon-bpu-ptq` / `bpu-quantize` | 升位宽还须过 CPU=0 |
| 视觉管线按采集/推理/显示拆 | `camera-usb-rgbd` | USB 物理层仍先于应用 |
| tros 与 Humble 分源 | `ros2-robotics` | 并列 overlay 仍禁止 |
| 长任务禁止短间隔反复 tail | `remote-ssh-dev` | tmux + 完成后再读产物 |
| 编译前探测 OE 包 / 板型 | `horizon-bpu-ptq` | 本仓仍按 TASK 隔离 venv，不强制 `.horizon` |

## 6. 明确不要从官方照搬

| 官方常见默认 | 为何不进本仓公理 |
|--------------|------------------|
| 向 Agent 要板端 IP/密码/`sshpass` | 违反 `privacy-github` |
| nash-p 全链路 body fp16 | 易破驻留或与已过门 w8 包冲突 |
| HMCT cosine≥0.99 停刀 | 校准余弦≠任务；看图/TTS 另有门 |
| `enable_mem_lru=true` 作 perf 默认 | 跨帧 LRU 可吞 ION，须对照开关 |
| 多模型同 session 当可并发持有 | IOVA 粘滞；评测一 boot 一主管线 |
| UCP 代码才算部署完成 | 本仓 Python/`run()` 任务门即可验收 |
| 把 OE-LLM 包与标准 OE 混装 | 版本/venv 踩踏 |
| BSP 刷机、擅自 reboot | Agent 禁止 reboot |
| 手补丁 AVB boot DTB 匀 ION | 整槽哈希失败并复位；走 embedded-ab-avb-boot |
| 把 91 个官方 skill 装进个人仓 | 抢上下文、与现场门打架 |

## 7. SOP（引用官方时）

1. 用 §3 打开对应 `SKILL.md`，核对版本身份（X vs S、`.bin` vs `.hbm`）。
2. 命令在部署机执行（`remote-ssh-dev`）；文档只写角色与 `<project_root>`。
3. 若官方步骤要改系统（headless、drop_caches、写 YAML 编译）：先复述风险，等用户确认。
4. 数值进报告时分列：官方工具输出 vs 本仓任务指标 vs 独占墙钟。
5. 冲突写入 investigation「官方默认 / 本仓门禁 / 采用哪条」。

## 8. 相关

- `horizon-bpu-ptq` / `edge-accel-eval` / `edge-accel-improve` / `edge-bpu-runtime-iova` / `community-edge-npu`
- `embedded-ab-avb-boot` / `edge-board-system-test`
- `remote-ssh-dev` / `camera-usb-rgbd` / `ros2-robotics` / `field-validation-method`
- `privacy-github` / `author-cursor-config`
