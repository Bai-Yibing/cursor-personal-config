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
- **Leap 校准必须走过导出图同一套 fakequant**：`build()` 里的 `ConstFakeQuant` / `qk_matmul` / `wv_matmul` 若只在导出路径出现、torch `forward` 仍走裸 `matmul`，absmax 会停在 0，HBM scale 落到 eps；编译仍可能 `cpu/hybrid=0`。校准 `forward` 必须调用与 `build()` 相同的量化节点，并在编译 JSON 里记录 absmax。
- **T=1 对齐不能代替 T>1 layout**：卷积/序列维若 `leap.reshape` 漏了与 `torch.transpose` 对等的轴交换，decode `seq=1` 仍可高 cosine，prefill `T>=2` 会掉到接近 0 或负数。
- **单层 isolate 高 cosine 不能证明融合前缀**：w8 块可能系统性缩小 RMS；下游层若直接吃未对齐的 hidden，会复现整段融合包的误差。拼接对照时要记 RMS gain，不能只报 isolate。
- **部署域重校准注意力前先做 same-feed**：把 HBM 残差×RMS 再编进注意力层，可能几乎不改 absmax，融合 cosine 还会更差。先比「同一 xs 上 HBM 注意力 vs float 注意力」和「float 注意力(xs) vs 全 float 下游」。若前者仍高、后者已掉，漏斗在残差内容被注意力放大，不要再按该配方编更深注意力。
- **段间 RMS 胶水有上限**：host 标量 gain 不能把已漂 hidden 拉回 teacher。需要的恢复量要用 teacher 混合（lerp）标定；到不了就换融合图或改量化，而不是再叠一层 RMS。
- **HBM 对 float 断崖要先跟 host 量化仿真三方对照**：若仿真贴 float、HBM 贴仿真失败侧，漏斗在 convert，不在校准 `forward`。量化 RMSNorm 默认可能系统性改 RMS；`preserve_precision` 双路径包（不覆盖默认交付）可把浅层/融合 hidden 拉回仿真。这只证明 convert 契约，不等于 greedy/板上生成。
- **isolate 注意力加宽或去掉 matmul ConstFQ 的收益不能写入融合包**：单层 stitch 上升时，整网 hidden 仍可能不变或更差。对照必须同时跑融合 hidden，禁止用最深一层的局部配方覆盖默认交付。
- **cache / Prefill 窗必须盖住产品 token 预算**：视觉 token 数（如一张图数百）大于语言 `cache_len` 或 Prefill `T` 时，该语言包不能当完整看图路径。短窗包只做文本烟测。
- **超长无 past Prefill convert 崩溃不要同图重试**：导出 `.bc` 成功仍可能在 convert SIGSEGV。先腰斩序列做探针；过了再考虑短 chunk + KV past 覆盖产品 token，而不是一次顶满。完整质量另开门禁。
- **腰斩 T 过了不能跨尺度抄**：小模型某 T 能 convert，更大 hidden/更深的同 T 仍可能 SIGSEGV。每个尺度自己探针；失败立刻改 chunk+past，不要假定「兄弟模型的成功 T」可复用。
- **两个大 leap convert 不要并行**：同机双任务会抢 CPU 或被中途杀掉。封 CPU 集串行，一步失败仍可继续下一步。串行函数里 `set -e` 下不要 `return` 非零，否则整条队列停掉。
- **齐套 stamp 不等于上板**：编译 `link_ok` 后打 stamp，带 IO 契约和 sha，默认不挂 latest。语言 HBM 体积随 hidden/层数涨，解压前先核磁盘。同包里的短窗 extra 不得与产品 path 同会话加载。
- **主机逐步 Decode qemu 不能当全链路看图门禁**：单步可到数分钟；全 prompt 展开不可作为本机验收。质量放到板上或更快 runtime；不要把小模型 qemu 墙钟抄到更大 hidden。
- **compile_hbo 到 100% 仍可能 LLVM vgpr**：大二维 VPU 注意力（视觉 784×784 或长 Prefill）会在链接前崩。减层、关 enable_vpu 若仍留下大 attn 就不要同图重试；先缩 grid / 缩 T。
- **检测框 cosine 高不能证明分类可用**：cls 正峰被压扁后 sigmoid 停在 ~0.45、NMS 对不上。先核对预处理 scale 是否贴 ONNX 输入域（例如 NV12 `1/255` vs 0–255）；域对了再拆 FPN/Detect。
- **静态 Prefill 短句要右齐进窗**：左齐可复读。公版 greedy 首 token 是数字时，不要当 Prefill 量化失败；再查 Decode 第二词是否早停。
- **板上能 load/run 不等于 greedy 对**：Prefill 最后一格已经抽错词时，不要先改 cache 左右对齐或 Decode。先看 Prefill logits top-k，再做主机三方。
- **视觉 HBM cosine 过 + leap 语言 greedy 过，不能证明语言 Prefill HBM last-real**：抽词必须用真实最后一格，不要用 chunk pad 格。leap 贴 teacher 只过到仿真层。
- **校准 thinking/chat 开关必须与评测一致**：开 thinking 校准、关 thinking 评测会让仿真 VL 首词跑到模板 token。产品校准跟板上同一开关。
- **last-slot 先无 qemu 的 w8 仿真，再 HBM qemu**：仿真不过禁止过夜 convert。仿真贴 leap、HBM 抽 EOS/乱词 → 漏斗在 convert/HBM logits，不是校准 `forward`。关 thinking 重编带 lm_head 的包仍可能失败；下一刀是去 lm_head 的 Prefill 或 Decode 展开，门禁未过不 pack。
- **主机整段 greedy 失败不等于图已死**：拆空 cache t=0、leap-KV oracle 一步、unroll/merge 累积。oracle 贴 teacher 时优先查调度脚本；t=0 就不贴才把 convert/IO 放进漏斗。
- **整窗 KV cosine 均值可被 pad 稀释**：只报 last-real / 有效 token 格。窗首格≈1、均值 0.3 不能当「KV 全坏」。
- **NV12 `input_type` 通常不支持 ddr**：精度 SKU 走 RGB featuremap 同 feed；pyramid NV12 只在板上用真实 ISP 验收。不要用 qemu 喂 Y/UV 当相机包精度门。
- **GQA-repeat 用 `concat([x]*ratio)` 可在 convert 后毁掉 mixer**：host w8 sim 仍可贴 float。改 `tile` 沿 repeat 轴（双路径后缀，不覆盖 concat 包）。GQA isolate 高 cosine 不能证明含该 repeat 的融合 mixer。
- **残差域重校准若与 embed 校准逐位相同则否证该刀**：先比 IO quant scale 与 same-feed hidden，不要连夜重编。
- **多核 HBM 主机 qemu 停在 Model Input Info 不能当卸载失败**：load 过仍可能 qemu 挂死；少核去喂会被 runtime 拒绝。数值放到板端 `device` 或已验证的单核路径。
- **HBM greedy 默认跟 host 量化仿真同岔，不自动等于公版 generate**：cosine / `_rmspp` 只能证明 convert 契约。弱提示可语义跑飞；对话模板另测。
- **板端时延必须独占加速器并记录频率**：并发占核的墙钟不能当芯片能力；CPU pin 与 live governor 可能只改变 pre/post，不改变 `rt.run` infer。
- **同 feed 才可比**：主机 verifier / 板端 / float 对照必须同一预处理、同一输入张量域；跨域数字只能当线索。
- **校准张量域必须贴导出/板上喂数**：0–1 letterbox 的图用 0–255 校准，大模型分类可被压死；校准 npy 上的高 max_prob 可以是错类虚荣。域对齐后再谈 FPN/头。
- **自回归 tok/s 由 Decode T=1 决定**：Prefill 窗（T=8 vs T=64）只改 TTFT。不要为提 tok/s 把 greedy Decode 编成 T>1，那是另一张图。
- **语音 LLM 先做 host w8 前缀仿真再 convert**：depth-1 hidden 已塌则漏斗在配方/注意力 V，不要整网重编去抢另一路 Leap convert。另一套同架构模型仿真仍可贴 float。
- **产品关 thinking 时板上必须禁采样 think 块**：空 `<think></think>` 模板会把看图句打成闲聊/套话。链路通 ≠ 内容贴教师。
- **大 Prefill load 前释放其它加速器/ION 占主**：常驻压缩/视觉 daemon 可让齐套 load `RESOURCE_EXHAUSTED`；停占主后再 load，会话结束 Release。
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
| 相机 NV12 vs 软件精度 | **双 SKU**：精度 RGB-fm+ddr；速度 NV12 pyramid | 勿编 nv12+ddr；qemu Y/UV ≠ ISP |
| 立体/复杂迭代图 | 多段 HBM + 等价改写 | Feat/Init/Update 等分段独立验收 |
| 多核加速器 | 只给**算力墙**段升 `core_num`；量化配方不变 | 搬数墙段优先减 DDR/复用，勿默认全段双核 |
| 几何采样触顶（深度） | ROI/更高部署分辨率/微调 | PTQ 无法突破 mm/px 几何下限 |
| 厂商 attention 不可导出 | 先做数值等价标准算子导出层 | 导出对齐过门禁再进 PTQ |
| 新位宽/新配方 | 双路径门禁过才替默认交付包 | 失败立即 rollback 到已验收基线 |
| GQA/K-V 头数比>1 的 repeat | 默认 concat 若 HBM≪sim 则双路径 `tile` | isolate 注意力过 ≠ mixer/融合过 |
| 多 SoC 同 ONNX | 按 march 分编（如 nash-e/m/p） | 演示可用 ORT/CPU 旁路，勿与全 BPU 质量门混报 |

## 4. 标准操作流程 SOP

1. **任务落盘**：`layout_ensure <TASK>`；三分区路径；不拷贝他 task 产物作依赖。
2. **隔离**：一长编译一容器/一 GPU；并行任务必须换容器换卡。
3. **边界与导出**：从在线调用图定静态段 → 导出等价层 → float 多指标对齐（相对参考实现）再进量化。
4. **校准**：输入分布对齐部署域；记录 rms/长度/语种桶；**禁止**默认 randn pad；calib 与 held-out 拆开。
5. **编译**：等待**产物落盘** + 成功收尾日志；进度 100% ≠ 完成。中断保留 `.bc`，可跳过校准续编。
6. **门禁**：目标段 CPU=0、无 hybrid（或文档诚实标 HYBRID）；advice/分段报告无意外 `external_cpu`。
7. **主机冒烟**：加载、输入名/shape/`input_type` 契约、段调用顺序；修 mask/dtype/prefill **再**判量化。语言 Prefill 抽词漏斗：leap last-real → 无 qemu 的 w8 仿真 → HBM qemu；仿真不过不开过夜 convert。
8. **板端深评**：同 feed 质量门 + 独占分段墙钟；**完整 md 报告**（模型/硬件/软件）见 `edge-accel-eval`。禁止用核数或编译器 FPS 代替板端段表。
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
| 编译驻留过、HBM vs float cosine 接近 0、KV/matmul scale 为 eps | torch 校准 `forward` 没调用 `build()` 里的 fakequant | 对齐官方 leap 图的 `cache_*_fq` 与量化 matmul；看 calib absmax 是否为 O(1)+ |
| decode T=1 高 cosine、prefill T>1 接近 0/负数 | 序列/通道轴在 leap 图里和 torch 不一致 | 用最短 T>=2 探针；补与 `torch.transpose` 对等的 `leap.transpose` |
| 单层 isolate ~0.98、融合前缀 ~0.58 | w8 块 RMS 漂移，下游吃未对齐 hidden | 记 RMS gain；拼接时 rescale 或拆段验收 |
| 部署域重编注意力后融合更差、absmax 几乎不变 | 漏斗是残差内容而非该层 HBM≠float | same-feed 拆开；停该注意力配方 |
| RMS 对齐后深层 cosine 仍掉、lerp 要 50% teacher 才回 0.84 | 标量胶水到顶 | 换融合段或量化，不叠 RMS |
| isolate 高、host 仿真也高、HBM 在浅层就开始掉且 RMS 被放大 | 量化 RMSNorm 进了 convert | 三方 cosine；双路径 `preserve_precision`；不覆盖默认包 |
| 单层去掉 attn ConstFQ / 加宽 V 或 Q 有局部收益 | 只改了最深注意力，融合图仍量化 LN | 必须重测融合 hidden；局部收益禁止当默认交付 |
| packed cosine>0.98 但末 token argmax 仍错 | 近并列 logits；convert 的 lm_head 与仿真不一致 | 记 margin；仿真 last-argmax 对照；勿把 cosine 当 greedy |
| leap last-real 贴 HF、视觉 cosine≥0.95，HBM last-real 抽错/EOS | convert 后 lm_head，或把 pad 格当真实格 | 先比 pad vs last-real；再跑无 qemu 的 w8 last-slot；仿真过再 qemu |
| 校准开 thinking、评测关 thinking，VL 首词变成模板词 | chat 模板域错 | 校准与评测同一 `enable_thinking` |
| w8 last-slot 过、HBM last-slot 抽 im_end | convert/HBM logits | 不重编同一 lm 图碰运气；探针 KV 或去 lm_head；未过不 pack |
| 主机 Decode unroll greedy 错、leap-KV 一步却贴 teacher | 调度/merge/累积，不一定是 Decode convert 死亡 | 同时打 t=0 与 oracle 一步 |
| KV packed 均值很低但第 0 格≈1 | 均值混进 pad | 只比有效格 / last-real |
| NV12 包 qemu 召回低、工具链拒 nv12+ddr | pyramid 契约 ≠ 软件张量门 | 精度走 RGB-fm；NV12 只板上 ISP |
| mixer HBM hidden≈0.29、host w8 sim≈1、拆段拼接≈1 | `concat([q]*ratio)` 一类 repeat 进 convert | 双路径 `tile`；不覆盖 concat 默认包 |
| 残差校准包与旧包 hidden 逐位相同 | 校准域没改到激活 | 停该配方；比 IO scale |
| 四核 HBM load 过、qemu 停在 Input Info | 主机 nash qemu 不支撑该核图 | 板上 device；禁止少核去喂 |
| 多核 3D 体积图 Recv misplaced，小图探针却能链上 | 不是单一维奇数/偶数 | 最小核图否证该假设后改切分轴或核数；全图成功前不算过 |
| 多核体积图 Recv，切分轴能链上但头层量化 cosine 崩 | 切分改变了校准/调度形状 | 切分维 pack 进 batch 成单 Conv；独立 workdir；float 与原图 maxabs=0 再编 |
| Prefill 长 T convert SIGSEGV，Decode 同配方已出盘 | 无 past 大静态图超 convert 预算 | 停同 T 重试；腰斩 T 探针；短 chunk+past 或 T=1 Decode |
| 小模型腰斩 T 过、大模型同 T 仍 139 | 图规模随 hidden/层数涨 | 每尺度单独探针；失败改 past 分块 |
| 串行队列探针失败后 path B 没启动 | `set -e` 下 `return` 非零 | 捕获退出码；失败也进入下一步 |
| HBM 已出盘但无板端包 / 误挂 latest | 把编译驻留当成交付 | stamp + sha + PACK_NOTE；不改 latest |
| 主机 qemu 跑不动完整看图 | 逐步 Decode 墙钟随图规模涨 | 单步只证 finite；全链路上板 |
| compile 进度 100% 后无 HBM、报 vgpr | VPU 注意力二维过大 | 禁同图；缩分辨率/序列或切段 |
| 框 cosine≈0.98、max_prob≈0.45、NMS 对不上 | 输入域或 FPN；头可能不是第一刀 | 先对 scale/ONNX 域；再同 feed 看 FPN |
| n 档 0–1 能出框、l 档 max_prob≈0.17 | 校准 npy 是 0–255、部署是 0–1 | 同图 `/255` 重校准；勿把头 fp16 |
| 板上 VL 出完整中文但三图同一套话 | 语言 last-real 或 think 采样 | 禁 think 采样；再比 last-real 与 float 教师 |
| 语音 LLM convert 前 host w8 depth-1 cosine≈0.25 | 配方/V 路径，不是缺 convert | 停整网重编；先改可导出 V/cache |
| Prefill 849MiB load RESOURCE_EXHAUSTED | 其它进程占 ION/BPU | 停占主 daemon 后再齐套 load |
| 板上 load 过、短句答成错误数字/早停 | Prefill 最后一格 logits 已偏 | 先打 Prefill top-k；再 host 三方；勿先改 merge |
| 两个大图 convert 同时跑，一个无 HBM | CPU/内存争用或会话被切 | 串行 + CPUSET；一步失败继续下一步 |
| 语言包能 load，看图 prompt 直接越界 | `cache_len`/`chunk` < 视觉 token+模板 | 先数 token 再选窗；短窗包不打 VL 交付标签 |
| 同 HBM 时延一次 27 ms、独占后又 20 ms | 并发占核或频率未记录 | 独占加速器；JSON 记录 CPU/BPU 频率 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 进度条=完成 | UI ≠ 产物 | 检落盘与成功日志 |
| 进度条冻住=进程死 | HBDK 可长时间不刷条但 CPU/RSS 仍忙 | 看进程与产物 mtime；勿当崩溃重启 |
| 同图同 T 再跑一次 convert 救 SIGSEGV | 会再崩并占内存 | 缩短序列或改 T=1 / 带 past 分块 |
| 两个尺度的大模型同时 convert | 互相拖死 | 串行封核 |
| 能加载=可上线 | CPU 段可藏很深 | profiler + 板端指标 |
| 大面积 sensfp16 / 头层强 fp16 | 常破门禁或极慢 | Softmax/LN 等白名单；头保持 int |
| 单点校准 cosine 当验收 | 域错时仍可「看起来还行」 | 多指标 + held-out + 板端任务 |
| host 与板端跨域对比当 bug | 假「板端神秘塌缩」 | 同 feed 诊断 |
| 短序列 randn×scale pad | 校准 rms 掉到噪声域 | 真实 pad/滑窗；randn 仅显式开关 |
| 只在 `build()` 放 fakequant、校准 `forward` 用裸 matmul | 导出图有量化节点但 absmax=0，HBM scale 成 eps | 校准路径与导出路径共用同一套量化算子 |
| 只用 T=1 decode 验收含卷积的序列图 | T=1 看不见时间轴交换 | 最短 T>=2 与 T=1 对照 |
| 把 isolate 层 cosine 当融合包质量 | RMS 漂移会在拼接处放大 | 融合前缀 + RMS 对照 |
| 用部署域残差×RMS 连编注意力仍无提升 | 可能在放大已漂 hidden | same-feed 先否证该层 HBM |
| 只跟 leap-float 比、不跑 host 量化仿真 | 会把 convert 病当成 PTQ 配方病 | 同一 feed 做 float / sim / HBM 三方 |
| leap greedy 过就 pack 语言 HBM | 语言 convert 可单独毁掉 last-real | 必须 HBM last-real 贴 leap |
| 主机 greedy miss 就停用整张 Decode/Prefill 图 | oracle 一步仍可能贴 teacher | 先拆 t=0 / oracle / unroll |
| 用整窗 KV cosine 均值判 KV 废 | pad 格稀释 | last-real 格 |
| qemu 喂 NV12 Y/UV 当相机包精度门 | 与 pyramid 板端不是同一契约 | RGB-fm 同 feed；NV12 上板 |
| 用 Prefill T=64 宣称 tok/s 提升 | 窗只改 TTFT | 分段报 Decode T=1 `run` 墙钟 |
| 有限值 WAV / CER 未过就宣称 TTS 可用 | 链路通 ≠ 听感 | Whisper 对目标句 + 分层 oracle/freerun |
| 校准 npy 高 max_prob 当检测过关 | 可能是错域错类 | 与 float ONNX 同预处理对照类名 |
| 融合 mixer 崩就先改校准/去 FQ | sim 已贴 float 时漏斗在 convert 图 | 先拆 mixer 子图再改 repeat 原语 |
| 多核包主机 qemu 挂死就重编 yaml | load 与 I/O 可能已过 | 先板上 device；勿少核喂 |
| w8 last-slot 不过仍开过夜 Prefill convert | 占核且漏斗已在校准 `forward` | 先修校准/图再编 |
| 校准与评测混用 thinking 开关再编一次 | 域错被当成量化噪声 | 先对齐 chat 模板 |
| 把 isolate 加宽或 no-FQ 写进默认融合包 | 融合 hidden 可以完全不跟 | 双路径后缀；融合对照过了再考虑替换 |
| 板端与压力任务抢同一 BPU 核后报时延 | 测到的是争用墙钟 | 独占核并记录频率 |
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
- 板上质量/速度深评与报告：`edge-accel-eval`
- 评完按层提速/提质：`edge-accel-improve`
- 多模型加载 / IOVA：`edge-bpu-runtime-iova`
- 语义检测上板：`semantic-occupancy-fusion`
- 远端执行与取材：`remote-ssh-dev`
