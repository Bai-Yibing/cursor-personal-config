---
name: horizon-bpu-ptq
description: >-
  Edge NPU/BPU post-training quantization and on-device deployment methodology.
  Use when running hb_compile or similar toolchains, packaging HBM or binary
  artifacts, gating CPU fallback segments, tuning PTQ precision, splitting
  unsupported graphs, multi-core scheduling, calibration domain matching
  (same-feed host vs board, no randn pad, calib≠held-out), layered AR/speech
  acceptance (oracle≠freerun), runtime contracts before recompile, export
  numerical parity, task isolation under STORAGE_LAYOUT, validating on-board
  latency and task metrics, or isolating per-task host Python/venv (OELLM,
  leap compile, no shared softlinks).
---

# 边缘 NPU/BPU 量化与部署方法论

工作路径仅用 `<ptq_workspace>`。编译成功 ≠ 全加速器 ≠ 板端可用 ≠ 任务达标。

## 1. 问题定义

将深度模型部署到嵌入式加速器（NPU/BPU/DSP 等）时的改图、量化、分段、上板与验收。典型失败：算子落 CPU/hybrid、进度 UI 误导、校准域与部署分布错位、跨域对比当门禁、敏感层强 fp16 破坏门禁、单点余弦当精度、oracle 路径冒充开放域质量、运行时契约当量化病重编、未做板端 profiling、多任务抢同一编译容器、跨 task 拷贝产物当依赖。

## 2. 不变量 / 第一性原理

- **优先级**：全加速器门禁（CPU/hybrid=0）→ 任务精度 → 墙钟速度。不为提速或「敏感层 fp16」牺牲门禁。
- **加速器常驻**：目标子图无意外 CPU/hybrid；否则延迟与确定性不可控。
- **校准域对齐**：校准激活分布须贴近部署（近距视差、真实 latent、真实 RGB、真实 AR 轨迹）；错域可过门禁却毁掉任务指标。
- **同 feed 才可比**：主机 verifier / 板端 / float 对照必须同一预处理、同一输入张量域；跨域数字只能当线索。
- **calib ≠ held-out**：评测集不得再当下一轮校准；同矩阵重编若零收益则停。
- **静态图 vs 自回归运行时**：固定 shape 视觉前端可单次推理打包；LLM/VL/TTS Talker 动态图用独立 runtime（System1+System2）；运行时 mask/dtype/prefill 契约须与编译一致。
- **分层验收**：load / finite / 链路通 / 质量 分列；oracle 残差路径 ≠ 全自由 freerun；联调 e2e_ok ≠ 语义正确。
- **板端是真相**：开发机 cosine/编译 latency 不可替代板端墙钟与任务质量。
- **墙钟 ≠ 加速器时间**：全 BPU 后 host/DDR/H2D 仍可占大半；要分段 profile。
- **按 TASK 隔离**：每 task 独立脚本/配置/venv/产物树；禁止把兄弟项目 ONNX/HBM/calib 当运行时依赖；SoC march 按目标芯片分编。
- **按 TASK 隔离主机 Python**：每个 `task/<TASK>/` 各自独立 `.venv`；禁止项目根 `.venv`/`.venv_oellm`；禁止 task 间软链共享；解释器须项目内基座 + `venv --copies`，禁止链到外置宿主机还原树。

## 3. 架构/选型决策树

| 情况 | 路径 | 备注 |
|------|------|------|
| 整图算子全支持 | 单包静态图 | 最简调度 |
| 不支持/易落 CPU 算子 | **先改图**再 PTQ | ScatterND/ConvTranspose/Resize/Einsum 等；改写为驻留，不指望靠它提精度 |
| 大双线性 Resize 触 VPU 限 | 通道切分×2 再 Concat 等等价改写 | float 先 cos=1 / maxabs=0 再编 |
| 部分图仍过大 | 图拆分 + 主机拼接 | 记录段间 I/O 与调用顺序 |
| 在线系统含动态控制流 | **从在线调用图推静态边界** | 缓存一次编码、按边关联；PGO/SVD/关键帧选留主机 |
| 大模型多子系统 | System1(NPU) + System2(LLM runtime) | 不赌单包塞全部 |
| 检测/分割头 | 全加速器；头输出 logits，后处理再 sigmoid | 头层强 fp16 易 `external_cpu` |
| 立体/复杂迭代图 | 多段 HBM + 等价改写 | Feat/Init/Update 等分段独立验收 |
| 多核加速器 | 只给**算力墙**段升 `core_num`；量化配方不变 | 搬数墙段优先减 DDR/复用，勿默认全段双核 |
| 几何采样触顶（深度） | ROI/更高部署分辨率/微调 | PTQ 无法突破 mm/px 几何下限 |
| 厂商 attention 不可导出 | 先做数值等价标准算子导出层 | 导出对齐过门禁再进 PTQ |
| 新位宽/新配方 | 双路径门禁过才替默认交付包 | 失败立即 rollback 到已验收基线 |
| 多 SoC 同 ONNX | 按 march 分编（如 nash-e/m/p） | 演示可用 ORT/CPU 旁路，勿与全 BPU 质量门混报 |

## 4. 标准操作流程 SOP

1. **任务落盘**：`layout_ensure <TASK>`；三分区路径；不拷贝他 task 产物作依赖。
2. **隔离**：一长编译一容器/一 GPU；并行任务必须换容器换卡。
3. **边界与导出**：从在线调用图定静态段 → 导出等价层 → float 多指标对齐（相对参考实现）再进量化。
4. **校准**：输入分布对齐部署域；记录 rms/长度/语种桶；**禁止**默认 randn pad；calib 与 held-out 拆开。
5. **编译**：等待**产物落盘** + 成功收尾日志；进度 100% ≠ 完成。中断保留 `.bc`，可跳过校准续编。
6. **门禁**：目标段 CPU=0、无 hybrid（或文档诚实标 HYBRID）；advice/分段报告无意外 `external_cpu`。
7. **主机冒烟**：加载、输入名/shape/`input_type` 契约、段调用顺序；修 mask/dtype/prefill **再**判量化。
8. **板端**：同 feed 对照；BPU 时间与墙钟分开记；分层质量指标相对基线。
9. **打包**：带时间戳 + rollback；latest 只指向验收包；半成品不覆盖最优交付。

## 5. 度量与门禁

| 门禁项 | 通过标准 |
|--------|----------|
| 产物就绪 | 二进制/HBM 落盘 + 成功日志（不信进度条） |
| 加速器居留 | 目标段 CPU=0、hybrid=0；profiler 无意外 fallback；HYBRID 须显式记录 |
| Float / 导出对齐 | 改图或导出后相对参考：多指标（cosine / L2 / 任务头）过阈值 |
| 校准域 | 激活落在部署典型区间；**held-out ∩ calib = ∅**；窗长/rms 与产品 builder 一致 |
| 同 feed 对照 | host quant / board / float 用同一 feed；跨域数字不进门禁表 |
| 延迟 | 板端墙钟满足帧率；同时报告加速器时间与 host/DDR |
| 精度（静态） | **多指标**任务验收；禁止只盯单节点校准 cosine |
| 精度（AR/语音） | 分层：oracle 路径 / 条件 TF / freerun；后者不过不得宣称「能说/能听写产品级」 |
| 错误预算 | board≈float 时停同域 PTQ，改解码/数据/切段/上游 |
| 版本 | 输入名/shape/`input_source`/精度/调用顺序/多核绑定与文档一致 |

## 6. 故障分类学

| 症状 | 可能原因 | 否证测试 |
|------|----------|----------|
| 进度 100% 无文件 / 收尾挂死 | 异步失败或 HBDK 僵死 | 查日志末尾与产物 mtime；单段重启，不动已完成段 |
| 容器中途退出 | OOM/抢卡/exec 会话断 | 保 `.bc` 续编；查主机 RAM 与 GPU 独占 |
| 加载成功但极慢 | ConvTranspose/Resize/Scatter 等落 CPU | 分段 profiler + advice Device 列 |
| 门禁过但任务指标崩 | 校准域错误；或 kl/头层过激 | A/B 换真实域校准；回退上一配方 |
| host 好看、板端塌一半 | **评测域 ≠ 校准/冒烟域** | 同 feed 重测；查 feed_cos |
| 敏感层 fp16 后更慢 | 算子打回 CPU/hybrid | 对照 CPU 段计数；废版 |
| 双核无收益或更慢 | 瓶颈在 DDR；或加载顺序/IOVA | 只核对称量段；先 load 重段再轻段；多模见 `edge-bpu-runtime-iova` |
| 近距深度 mm 级无解 | 部署分辨率下视差采样不够 | 算 mm/px 预算；ROI/分辨率/训练，而非加 calib |
| 板端花屏/尺度乱、量化 cos 仍高 | **输入契约错**（如 pyramid/nv12 当普通 RGB 张量喂） | 按导出 FLOAT 契约重喂；对照 float ONNX |
| 同矩阵再编零收益 | calib=held-out 或已触顶 | 停编；拆 held-out；改错误预算层 |
| oracle 路径过、开放/freerun 崩 | 开放域 hidden/code0 漂；或把 decode 链当 prefill | 分层 LISTEN/freerun；先对齐 runtime 契约与开放域校准长度 |
| 尾段手术无效 | 上游节点 cosine 已崩 | 读编译逐节点表；刀口移到首崩层 |
| 升 w8 后某路径崩 | 位宽/尺度不适合该子图 | 回退已验收位宽；禁止默认「更宽更好」 |
| 导出/PTQ 前数值对不齐 | 不可导出算子未做等价层 | 层对齐不过则阻塞编译 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 进度条=完成 | UI ≠ 产物 | 检落盘与成功日志 |
| 能加载=可上线 | CPU 段可藏很深 | profiler + 板端指标 |
| 大面积 sensfp16 / 头层强 fp16 | 常破门禁或极慢 | Softmax/LN 等白名单；头保持 int |
| 单点校准 cosine 当验收 | 域错时仍可「看起来还行」 | 多指标 + held-out + 板端任务 |
| host 与板端跨域对比当 bug | 假「板端神秘塌缩」 | 同 feed 诊断 |
| 短序列 randn×scale pad | 校准 rms 掉到噪声域 | 真实 pad/滑窗；randn 仅显式开关 |
| 评测集再当 calib 重编 | 零收益幻觉 | calib⊥held-out |
| oracle/path-C 当开放听感 | 测不出 freerun 崩 | 分层门禁；产品锁已过基线 |
| rms/能量回升当质量过关 | 首码仍可全错 | 盯 hidden cos / code0 / 任务指标 |
| 盲抬 EOS / max_new 救长句 | 可更差 | 先停步 logit 与错误预算 |
| 先盲编下一变体 | 契约/域问题被掩盖 | 先修 runtime 与同域对照 |
| 在已污染尾段空转改图 | 上游已崩 | 逐节点 cosine 定位 |
| 开发机宣布提升 | 温度/带宽/后处理不同 | 必须板端测 |
| 同容器并行长编译 | 抢 GPU/RAM，互相拖死 | 一容器一任务 |
| 为双核改量化配方 | 回到 CPU 慢路径 | 只改 `core_num`/调度 |
| 单包赌大模型 | 图超限 | System1+2 |
| 用实验室远景集校准近距机器人 | 激活分布错位 | 按本机 B/fx 与距离桶建校准 |
| 公开集当导航/语音精度基线 | 域不对 | 真实 rollout/场景矩阵为主 |
| 照搬他项目拆分段当公理 | 边界可能错 | 从本仓库在线调用图推导 |
| 跨 task 拷贝 HBM/ONNX/calib | 污染与不可复现 | 本 task 自建；只引公版源码/权重 |
| 根目录或 task 间软链共享 venv | 升级踩踏、路径语义乱 | 每 task 独立 `.venv` + `--copies` |

## 8. 交付/复盘检查清单

- [ ] 容器/GPU 隔离；**模型进 models 根、数据进 data 根**（三分区，禁止项目根堆大文件）
- [ ] 新 task：`layout_ensure`；未依赖兄弟项目产物
- [ ] 主机环境：每 task 独立 `.venv`（无根目录/软链共享）；python 为项目内 `--copies`
- [ ] 导出/改图 float 多指标对齐（若做过 surgery）
- [ ] 每段 CPU=0（或 HYBRID 已记录）、可加载、调用顺序与多核绑定已核对
- [ ] 校准域说明、窗长/rms、held-out 策略已记录；无默认 randn pad
- [ ] 同 feed 的 host↔board↔float 对照已做
- [ ] AR/语音：分层门禁与产品默认包（含 rollback）已写清
- [ ] 输入契约（dtype/layout/`input_source`）与文档一致
- [ ] 废版备份与 rollback；未覆盖最优基线
- [ ] 板端：加速器时间 + 墙钟 + 任务多指标
- [ ] 汇报标注 `<ptq_host>`、包路径占位符、时间

## 8.1 存储布局（边缘 PTQ）

模型产物与校准/日志/交付包**分根**：`<models_root>` vs `<data_root>`；按 **TASK** 分子目录。编译 scratch → `work/<TASK>/`，交付 → `packages/<TASK>/`。具体树与迁移脚本以仓库 `docs/STORAGE_LAYOUT.md` 为准。

## 8.2 主机 Python / 按 TASK 隔离 venv

| 约定 | 要求 |
|------|------|
| 位置 | 仅 `task/<TASK>/.venv`；**禁止**项目根 `.venv` / `.venv_oellm` |
| 共享 | **禁止** task↔task、根↔task 软链「省空间」；各 task 独立目录 |
| 解释器 | 官方 cp310 wheel → 项目内基座（如 `<ptq_workspace>/toolchains/cpython-3.10`）+ `python -m venv --copies` |
| 外置路径 | **拒绝** stereo / restore_* 等宿主机还原树；activate/setup 应检测并报错 |
| 轻量 task | 可用系统 `python3.x` + `--copies`，仍须独立 `.venv` 目录 |
| 容器 | 若解释器或 `home=` 指到容器外路径，容器内不可直接跑；leap 编译在能访问该基座的主机环境执行 |

SOP（OELLM / leap）：

1. 确认项目内 CPython 3.10 基座可用（bootstrap / `HORIZON_PYTHON310`，路径在 `<ptq_workspace>` 内）。
2. 默认 task：`bash scripts/setup_oellm_env.sh` → `task/<default>/.venv`。
3. 其他 task：`HORIZON_OELLM_VENV=<ptq_workspace>/task/<TASK>/.venv bash scripts/setup_oellm_env.sh`。
4. `source scripts/activate_oellm.sh`（按需设 `HORIZON_OELLM_VENV`）；拒绝软链与外置 python。

反模式：根目录软链到某 task venv；ASR 软链 TTS；直接用宿主机还原 Python —— 换机/容器失效、升级互相踩踏、路径语义混乱。

## 8.3 校准与评测卫生（摘要）

```text
部署域样本 → 建 calib（真实 pad/滑窗，禁默认 randn）
         ↘ 建 held-out（与 calib 不相交）
编译 → 同 feed：float | host quant | board
静态段：CPU/hybrid 门禁 + 任务多指标
AR 段：oracle → 条件 TF → freerun；后者过才升默认包
board≈float → 停同域 PTQ，改别的杠杆
```

## 9. 相关 skills

- 实验与置信度：`field-validation-method`
- 多模型加载 / IOVA：`edge-bpu-runtime-iova`
- 语义检测上板：`semantic-occupancy-fusion`
- 远端执行与取材：`remote-ssh-dev`
