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
- **Prefill `T` 与 `cache_len` 是两根轴**：`T`/`seq_len` 是一次 `run` 吃进的 prompt 块长，主要改 TTFT 块数；`cache_len` 是静态 KV/mask 宽，Prefill 与 Decode 必须同宽，主要改多轮/长生成预算。不要用加大 cache 冒充「Prefill 已经顶满」，也不要把厂商融合 YAML 的超长 cache 抄到另一套管线的第一刀 leap convert。
- **cache / Prefill 窗必须盖住产品 token 预算**：视觉 token 数（如一张图数百）大于语言 `cache_len` 或 Prefill `T` 时，该语言包不能当完整看图路径。短窗包只做文本烟测。
- **超长无 past Prefill convert 崩溃不要同图重试**：导出 `.bc` 成功仍可能在 convert SIGSEGV。先腰斩序列做探针；过了再考虑短 chunk + KV past 覆盖产品 token，而不是一次顶满。完整质量另开门禁。
- **腰斩 T 过了不能跨尺度抄**：小模型某 T 能 convert，更大 hidden/更深的同 T 仍可能 SIGSEGV。每个尺度自己探针；失败立刻改 chunk+past，不要假定「兄弟模型的成功 T」可复用。
- **两个大 leap convert 不要并行**：同机双任务会抢 CPU 或被中途杀掉。默认 `flock` 串行；一步失败仍可继续下一步。串行函数里 `set -e` 下不要 `return` 非零，否则整条队列停掉。用户确认跳锁时必须绑互斥 CPU 集；本轮已有双方 `link_ok` 的证据，仍禁止无限并行。`compile_hbo` 进度条 100% 不等于 `.hbo`/`.hbm` 落盘。
- **离散码本 / FSQ 的 Cast 必须盖住码值上界**：int8 饱和成常数后 HMCT cosine 仍可很高。门是 exact match 或非饱和直方图，不是 id cosine。同一躯干只钉 Cast/求和节点到 int16，不覆盖旧包。
- **静态最大长 pad 不等于有效序列长**：把短内容当满窗 `token_len` 喂注意力，听感会掉。用真实长度或显式零填充激活；结构 pad 不是内容。
- **词表 Gather 超过方言 index 上限会 HYBRID**：先读 `hbir.index` 容量。超了就切片或主机预切下标，不要整表硬编。
- **先打厂商官方格，再扫 chunk×cache 梯子**：对照 YAML/样例包的 chunk、cache、`core_num` 先编齐套（视觉/头/Prefill/Decode），合法格全入队但容器内串行。梯子空转不能替代官方 shape。`core_num=N` 不是 N 倍墙钟；多核 qemu 挂死不当芯片 FPS。
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
- **`cal_data_type=float32` 时不要假设编译器 `norm_type` 会改校准集**：校准 npy 必须预归一化到运行时分布，否则仍可干净编译、上板垃圾。
- **头内 `ScatterND` 锚点解码可编译成功且永不写 objectness/class**：切在 decode 前、运行时后处理；不要用「link_ok」当检测器可用。
- **LLM 不以 cosine 验收**：至少 Prefill↔Decode greedy 一致、held-out PPL、任务锚。VLA 再报 `‖a‖/‖a_ref‖`，并在同一 harness 打参考列；cosine 对动作幅度无感。
- **同 feed 才可比**：主机 verifier / 板端 / float 对照必须同一预处理、同一输入张量域；跨域数字只能当线索。
- **校准张量域必须贴导出/板上喂数**：0–1 letterbox 的图用 0–255 校准，大模型分类可被压死；校准 npy 上的高 max_prob 可以是错类虚荣。域对齐后再谈 FPN/头。
- **自回归 tok/s 由 Decode T=1 决定**：Prefill 窗（T=8 vs T=64）只改 TTFT。不要为提 tok/s 把 greedy Decode 编成 T>1，那是另一张图。
- **AR decode 运行时必须与 Decode 图同契约**：产品逐步生成是 T=1。把 Prefill 宽窗（T=64）当 decode 填槽、或相对位而非绝对 RoPE，可出现 Prefill same-feed≈1 而 teacher-force 第一步 cosine≈0.5。先修调度再怀疑量化。
- **多输入身份塌缩先查 convert 动态量化与 `llm_convert`**：同 feed 多图在 export `.bc` 仍可分，经 `dynamic_quant` 或 `llm_convert`（含 softmax skip/vae/vpu）后两两 cosine→0.99 且 rms 齐，漏斗在 convert。`maxabs>1e-4` 可与塌缩并存，live 门是图像间 cosine 不高。双路径 nodq（不覆盖默认）；`opt=0` 救不了。塌缩图常同时变成「快常量」墙钟，更快≠可用。
- **厂商 runtime 刷屏可主导墙钟且不改 greedy ids**：日志级环境变量可能无效。评测可静默 stdio；必须对照同一 token 序列。刷屏墙钟不得当芯片时延。
- **SoC `core_num` 上界是编译器硬范围**：某 march 报 `must be in range 1 to 1` 时升核 remap 会被拒绝，不是绑核写错。先读编译器范围再谈调度。
- **主机 qemu last-real 首词不能否证板端 greedy**：qemu 与 device runtime 可抽不同词；板上以齐套 `run` 为准。
- **语音 float 头 ≠ 全 BPU 产品**：logits 在 CPU 的 skip 包只证听感桥，不证加速器门。`force_n`/oracle Whisper 过 ≠ RAS freerun。主机 qemu 挂在 Model Input Info ≠ cosine/配方失败。
- **教师 greedy 吸同一循环 id 时，不要写成量化独有**：float greedy 也会塌；开放文本必须对照教师同款采样（如 RAS）。量化体 RAS 在相近 topk 上抽偏是 margin，不是 packing、不是缺 skip 重编。
- **缺 prompt 尾与峰塌是两洞**：短窗只装前缀会复读提示音；float 补 teacher-force 尾后 RAS 可逐位 native。量化 freerun 仍塌时先停采样超参，再动配方。
- **短窗切界失败不能写成估计器不能量化**：同一 Euler 在短窗多块失败、加长一窗过门，是窗长/重叠契约。先对齐产品 mel 长，再谈量化位宽。
- **加速器图质量失败时禁止把最重网搬到 CPU 当产品路径**：ARM 上的教师 LLM / 多步 Euler 是秒级，板上已有毫秒级 `run()`。质量工作留在校准/配方/调度，CPU 只做离散胶水（采样、分词、CIF）。
- **Prefill 逐步重灌是质量拐杖，不是速度 SKU**：绕过 Decode 时墙钟约 O(n)×Prefill。Decode 逐步 cosine 修好前可用来听感，交付速度仍看 T=1 Decode。
- **声码器链必须拆段归因**：浮点估计器+量化声码器过门、量化估计器无论声码器都失败，漏斗在估计器，不要重编整条 token2wav。
- **官方某 SoC 的 PPL/样例包不能当另一 march 的质量门**：可编 ≠ 任务达标；禁止把甲芯片官方 PPL 抄到乙芯片交付。
- **PTQ 仿真绑定已验证容器**：同一 `*_ptq_model.onnx` 在 GPU 容器崩溃、在 CPU 容器有限，不能用崩溃否证图。CIF/argmax 留 CPU 是产品结构，不是漏编。
- **图上拆 Softmax（Exp 等）不等于速度 SKU**：板上 `run` 仍可与 nodq 同量级；随图变只证明 live，不证明更快。
- **官方技能并进本仓，不另装一套**：命令和版本身份查 [rdk-skills](https://github.com/D-Robotics/rdk-skills) / [oe-skills-s](https://github.com/D-Robotics/oe-skills-s)，动手门禁以本节为准。2026-09-24 的技能包 S `v1.1.2`、X5 `v1.1.1` 只是索引版本。现场继续用 OE 镜像 `v3.7.0` 和 OE-LLM **1.0.2**。不因技能包号去换 `hb_compile`、刷板或把未安装的 OELLM 2.0 接进当前会话。Qwen3.5 不在 1.0.2 的 `model_name` 里，也不在手册 v1.0.5 的 Qwen3 清单里，继续走自有 leap。标准 OE 包与 OE-LLM 包分开，不混装。X=`.bin`，S=`.hbm`。官方也要求先 PTQ、探测已有 Docker 且不自动拉镜像；其全链路示例仍不得覆盖已过门的 w8 驻留包。没有打开的文档页不补参数。版本针见 `rdk-official-catalog`。
- **无证据不升混精度**：官方 router 亦禁止在全 int8 未证伪前主动升 int16/fp16；升位宽还须再过 CPU=0。HMCT cosine≥0.99 只是工具链探针。
- **QAT/导出一致性按阶段切**：`qat.pt` → `export.pt`/`pre_export` → `qat.bc` → `quantized.bc` → HBM/板端。单帧数值差不能跳阶段归因；须稳定 badcase。
- **编译 YAML 须确认后再 `hb_compile`**：官方 HBDK skill 强制；本仓另加双路径、不覆盖过门包。
- **官方性能工具分列**：`hrt_model_exec perf`、`hb_analyzer`、Perfetto `.pftrace`、`hrt_ucp_monitor`/`hrut_ddr` 可采集。高频监控不要走 gRPC `hbm_infer`。其 FPS 仍须按 `edge-accel-eval` 标独占与分段。
- **同 feed HBM cosine ≠ freerun 内容门**：Prefill logits≈1 只证数值契约。语音听感用 Whisper/CER；native/oracle token 过门不能代替 leap freerun。
- **语音 LLM 先做 host w8 前缀仿真再 convert**：depth-1 hidden 已塌则漏斗在配方/注意力 V，不要整网重编去抢另一路 Leap convert。另一套同架构模型仿真仍可贴 float。
- **产品关 thinking 时板上必须禁采样 think 块**：空 `<think></think>` 模板会把看图句打成闲聊/套话。链路通 ≠ 内容贴教师。
- **大 Prefill load 前释放其它加速器/ION 占主**：常驻压缩/视觉 daemon 可让齐套 load `RESOURCE_EXHAUSTED`；停占主后再 load，会话结束 Release。
- **calib ≠ held-out**：评测集不得再当下一轮校准；同矩阵重编若零收益则停。
- **复制相同校准样本加权不是新域**：max 校准对重复 npy 不改 absmax，HMCT 可逐位相同、听感不变。要新激活就刷不重复轨迹/前缀。
- **任务稀有 token 必须进校准**：描述图校准几乎看不见十进制 `0` 或 JSON 时，板上会把 `0` 抽成 `!`。只换独立头不够时，fused Decode 也要同域。应用层把 `!` 改成 `0` 不是生成门。
- **stamp dump 契约先对齐再谈 HBM**：seq / cache / n_img / 视觉 shape 与包不一致时直接拒绝。默认 vis448 T=64 cache_256 不能喂 T=112 cache_2048。抽词用 `last_real`，chunk 末格常是 pad。视觉输出必须 scatter 回 Prefill hidden。qemu 挂 Model Input Info 不能否证 `link_ok`，也不能当板上视觉失败。
- **工具链余弦 ≠ 听感 WAV**：HMCT / 校准 cosine 过、主机 PTQ mix Whisper 过，都不能代替编译 HBM 板上 `run()`。mix ONNX 与 HBM 不是同一产物。
- **逐文件相同 WAV 否证编译旋钮**：对照句 WAV sha 相同，则 compiler O 级或单节点 qtype 钉输出不是该句杠杆；停刷、换图或校准域。
- **独立头 overlay 同坏文则漏斗在体/KV**：hidden-only Decode 外接独立 `lm_head` 与 fused 逐步文本相同，否证 fused 头独因；下一刀是校准窗或体，不是再换头。
- **dump 秩与 runtime 对齐**：同元素 2D dump 对 3D `[1,…]` runtime 先 reshape / 加 batch，不要先当 dump 坏或重推包。
- **mix 声码器过不能证明 encoder HBM**：估计器 HBM 逐步可贴 PTQ，而板上 encoder μ vs PTQ 仍有 maxabs；CFM 会放大。先交叉：PTQ mel + 板上 vocoder。
- **未校准 host IR 余弦 1 不能否证校准 HBM 逐步命中**：同一前缀上 Qwen 与 leap 中间表示 `hidden_cos=1`、`top1_match=1`，只证导出图对齐。校准后的 HBM Decode 逐步 `hit_at_1` 仍须同 feed 另测。
- **句末单字 U+FFFD 且句号完好先查 byte-fallback**：整句通顺、词表无该字整词时，未闭合 UTF-8 加 `errors=replace` 会落成替换符。守卫只在 pending 字节未写完时改 argmax；整字 token 不限制。未拿到本轮 token id 前，不要重编 HBM。
- **字错率过不能代替听感门**：同句 CER=0 仍可能响度、过零比、频谱平坦度、log-mel 余弦不过。听感对照同一句的浮点声码器，不要用转写代替。
- **点积先收成 fp16 再除以 sqrt(d) 会变成全 0 hidden**：校准 |Q|·|K|·d 超过 fp16 上界（65504）时，点积变 Inf，两处 Inf 的 softmax 是 NaN，残差读出来是 0，argmax 落到 id 0。先缩放再收窄。文件名改了不等于导出图改了，要对照 mlir。输入加一个小偏置不是修复。
- **最终 RMS 的 fp16 平方溢出同样会把 hidden 清成 0**：元素绝对值超过 256 时 `x^2` 变 Inf，`rsqrt` 变 0，这一层替换残差。只在最终范数上把输入乘 1/8、eps 乘 1/64，实数里约掉，平方可撑到绝对值 2040。整层改成 fp32 能编过，但板上第一步可以永不返回。块内范数不要一起缩。
- **界面上的乱码消失不能记到未部署的守卫头上**：板上脚本里没有这段逻辑时，先记录用户观测，原因标待验证。不要据此重编。
- **系统提示和词表改字不是权重里的名字**：碎片 token 会碰到别的词。解码后替换只改显示。要模型自己说出新名字，就做不带系统提示的语言侧微调，再按同一张图重编，不覆盖正在用的包。浮点门禁不过不开编。
- **板上全 blank 若与主机 HBM qemu 一致，漏斗在编译后的包**：同 feed 的 PTQ ONNX 仍有非 blank 时，不要怪板端运行时或分词器。只钉一层、而 PTQ argmax 不变，就停掉这一刀。传输体积对不上的文件删掉，不拿它的结果当门。
- **固定窗困惑度不随 cache 变长而提高**：多出来的槽被掩码挡住，Prefill 和 Decode 墙钟变长。`cache_len` 超过模型位置上限时入口应直接拒绝。要更快就用已测过的短格，不把 cache 加到位置上限的两倍。
- **短提示左齐且 mask 把有效 key 放在 cache 末尾**：长度不超过半窗时最后一格注意力是空的，短文本会复读或打出 id 0。看图 prompt 更长时左齐仍可能正常。先改对齐再重编权重。
- **另一套 SDK 的公开困惑度不能当本包劣化**：协议和运行时不同。同机、同切分、同 token 重跑 float 之前，只报本包自己的数字。
- **首词是 think 标签则本轮 greedy 作废**：全 HBM 仿真未关 thinking 会先抽模板 token。丢掉该轮，用同一包、`enable_thinking=False` 重跑，再谈图或量化。
- **包装器 CLI 上限 ≠ convert 预算**：SDK argparse 的 cache/chunk 顶只是入口。放开环境变量后仍按 SIGSEGV 禁同图重试，不得把 CLI 顶写成编译器已证顶。
- **只清已链接格 scratch**：格内已有交付 `.hbm` 才删 `.bc`/中间 ONNX/重复 workdir HBM。未链接格保留 `.bc` 以便续编。不杀在跑 convert。
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
| 同一 npy 复制十份再编，HMCT 逐位相同 | max 校准不看重复计数 | 刷不重复轨迹；对照 absmax |
| 找物 JSON 解析期把 `!` 换成 `0` 过烟测 | 原始 greedy 仍是 `!` | 原始 bbox 必须是 `[0-9.]`；`gate_bbox_raw` |
| 描述图校准后板上数字槽抽 `!` | 校准几乎无十进制 `0` | 头与 fused Decode 都灌任务前缀 |
| 默认 vis448 T=64 dump 喂 T=112 cache_2048 | 契约错位 | stamp `--from-stamp`；错则拒 |
| 视觉 qemu 挂 Input Info 就当 vis HBM 坏 | qemu ≠ device | `link_ok` 另记；板上 `run` |
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
| Prefill same-feed≈1、decode teacher-force≈0.5 | 用 Prefill T 窗填 decode 槽或相对 RoPE | 改 T=1 + 绝对位置；对照教师逐步 logits |
| 多图 export 可分、mlir/HBM 两两 cosine≈1 | `dynamic_quant`/`llm_convert` 塌身份 | 双路径 nodq；勿只降 `opt` |
| hop maxabs>1e-4 但三图 cosine≈0.99、墙钟「变快」 | 身份塌成常量图；maxabs 虚荣 | live 门用图像间 cosine；任务 greedy 随图变 |
| Decode/视觉墙钟被日志刷屏抬高、token 不变 | 主机 stdio/spdlog 税 | 静默 fd1/2 对照同 ids；勿只改日志环境变量 |
| 升核 remap 报 `core_num` range 1 to 1 | march 编译器硬上限 | 停升核；速度另开质量门 SKU |
| 主机 qemu 抽「这张」、板上 greedy「三只」 | qemu ≠ device runtime | 以板端齐套 greedy 为准 |
| skip LLM Cpu=0 未过、float 头 CER=0 | float `lm_head` 不是全 BPU | 独立头图驻留后再开听感 |
| oracle/`force_n` Whisper=0、RAS freerun 糊 | 采样轨迹离 native | 分层；勿为听感改量化或升核 |
| float greedy 与量化 greedy 同吸循环 id | 教师解码器本身不用 greedy | 对照教师 RAS；勿为 greedy 循环重编 skip |
| 短窗两块 CER 高、加长一窗过门 | 切界/重叠，不是图不能量化 | 先改窗长对齐产品 mel |
| 量化估计器 CER 高、浮点估计器+量化声码器过门 | 漏斗在估计器 PTQ | 只动估计器校准/图；勿整条 vocoder 重编或改 CPU Euler |
| 开放句质量差就把 LLM/Euler 放到 ARM | 墙钟从百毫秒变成数秒 | 重网络留加速器；CPU 只胶水 |
| Prefill-only 听感过就当产品 tok/s | 每步重灌 Prefill | 速度 SKU 仍是 Decode T=1 |
| 甲芯片官方 PPL 过、乙芯片同名包未测 | 不同 SDK/march | 各 SoC 自己的任务门 |
| GPU 容器加载 PTQ ONNX 崩就当图坏 | runtime/容器 ABI | 换已验证 CPU 容器再测 |
| 短 Prefill 复读提示音、补 tail 后 float RAS 逐位 native | packing 洞已闭 | 量化 freerun 另开漏斗，勿混成一刀 |
| nash qemu 挂 Model Input Info、板上 finite | 主机 qemu 不支撑该图 | 板上 `run`；勿当 HBM 损坏重推 |
| LLM HBM cosine 过、leap freerun ASR 乱 | 采样/缓存/位置契约或配方残差 | 听感桥先 native/oracle token；再换 leap freerun |
| 板上 load 过、短句答成错误数字/早停 | Prefill 最后一格 logits 已偏 | 先打 Prefill top-k；再 host 三方；勿先改 merge |
| 两个大图 convert 同时跑，一个无 HBM | CPU/内存争用或会话被切 | 串行 + CPUSET；一步失败继续下一步 |
| 语言包能 load，看图 prompt 直接越界 | `cache_len`/`chunk` < 视觉 token+模板 | 先数 token 再选窗；短窗包不打 VL 交付标签 |
| 同 HBM 时延一次 27 ms、独占后又 20 ms | 并发占核或频率未记录 | 独占加速器；JSON 记录 CPU/BPU 频率 |
| 官方 cosine≥0.99 已过、看图/ASR 仍废 | 工具链探针≠任务 | 同 feed 任务指标；停同域刷余弦 |
| 按官方 nash-p 全链路改成 body fp16 | 驻留/已过门 w8 被覆盖 | 双路径；用户确认；不覆盖交付 |
| QAT 训练好、HBM 掉点就改校准 | 漏斗可能在 export/convert | 按 qat.pt→bc→HBM 分段 |
| 把 OE-LLM 组件装进标准 OE venv | 版本踩踏 | 分包检测；本仓按 TASK `.venv` |

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
| 把加大 `cache_len` 写成 Prefill 已顶满 | 两根轴 | TTFT 看 T 块数；多轮看同宽 cache |
| 先扫 chunk×cache 梯子再打官方 shape | 空转、占 convert | 官方格齐套后再往上或往下 |
| 码本 id cosine 高就当量化过 | int8 可全饱和仍高余弦 | exact match / 直方图；Cast 盖上界 |
| 把静态 max-len pad 当有效 `token_len` | 注意力吃进假长度 | 真实长度或零填充激活 |
| 整表 Gather 超 index 上限仍硬编 | 必 HYBRID 或失败 | 切片或主机预切 |
| 进度条 100% 当 `link_ok` | 文件可能尚未写出 | 等 `.hbo`/`.hbm` 与 sha |
| 用 Prefill 宽窗填 decode 槽做 freerun | 位置/注意力契约错，cosine 虚荣 | T=1 + 绝对 RoPE；对照教师逐步 |
| 有限值 WAV / CER 未过就宣称 TTS 可用 | 链路通 ≠ 听感 | Whisper 对目标句 + 分层 oracle/freerun |
| 复制校准文件当「加强 RAS 域」 | 重复样本不改 max absmax | 不重复轨迹；先比 HMCT 是否逐位相同 |
| 应用层修 JSON 数字当板上过门 | 只改解析 | 原始 greedy 无 `!` |
| 只用独立 lm_head 修 Decode fused 数字 | 数字 logit 在 fused 头 | Decode 同域校准 |
| 错窗 dump 仍硬跑 Prefill | 抽 pad / 形状炸 | 对齐 seq/cache/n_img |
| dump 缺 leading-1 就重 dump 整包 | 元素数已对，只是秩 | reshape / unsqueeze batch |
| HMCT≥0.98 或主机 mix CER 当板上听感 | mix ONNX ≠ 编译 HBM | 板上 `run()` Whisper |
| 对照句 WAV sha 相同仍升 O 级 / 钉 qtype | 该旋钮未改波形 | 停刷；换注意力图或校准域 |
| overlay 独立头仍同 `!` 就再只换 fused 头 | 漏斗在体/KV 或校准窗 | 同 feed 对照 overlay vs fused；改校准或体 |
| encoder HMCT μ≈0.99 仍刷估计器 qtype | mix 声码器已过，漏斗在 HBM μ | PTQ mel×板上 vocoder；再动 encoder 映射 |
| 未校准 host IR cosine=1 就宣布 HBM Decode 已修好 | 两套图不是同一量化域 | 校准 HBM 逐步 `hit_at_1` 另测 |
| 句末 U+FFFD 就重编整图 | 稀有字 byte-fallback 未闭合 | 先对词表 decode 同形；再 dump token id |
| CER=0 就当听感过 | 响度/过零/频谱仍可失败 | 同句浮点声码器五项再加 CER |
| 坐标全是 `!` 就只重校准 Decode | hidden 全 0 时 argmax 是 id 0 | 先查最终 RMS 的 fp16 平方；再查 QK 是否在缩放前收窄 |
| 整层 RMS 改 fp32 当溢出修复 | 能编过，第一步可以不返回 | 只缩最终范数的输入和 eps |
| 词表改品牌字符串 | 碎片 token 会改掉别的词 | 语言侧微调后按原图重编 |
| 一层余弦差就钉这一层 fp16 | PTQ argmax 可能不变 | 先看 argmax；不变就停 |
| 加长 cache 当精度或速度 | 固定窗被掩码挡住，墙钟变慢 | 短格做速度；长格只为上下文 |
| 短文本复读就重训 | 左齐 + 末尾 mask 使最后一格为空 | 右齐后再看权重 |
| 拿另一 SDK 的公开 PPL 写劣化 | 协议不同 | 同机同切分重跑 float |
| 首词 `<think>` 当 HBM 坏 | 模板开关开着 | 作废该轮；关 thinking 再抽 |
| 把 SDK argparse 顶当 convert 顶 | 入口限制 ≠ 编译器预算 | 放开包装上限后仍 SIGSEGV 即停同图 |
| 清未出盘格的 `.bc` 腾盘 | 续编断点没了 | 只清已 `link_ok` 格；保留失败格 |
| 只降 `opt` 救多图身份塌缩 | 漏斗在 dynamic_quant / `llm_convert` | 双路径 nodq；hop 用图像间 cosine |
| 用 maxabs>eps 当 hop live | 常量图仍可有差 | cosine 门 + 任务随输入变 |
| 把刷屏墙钟当芯片 tok/s | 日志 I/O 税 | 静默 stdio；对照 greedy ids |
| 某 SoC 视觉升核救 nodq 慢 | 编译器核数范围可能是 1 | 先读 range；失败停 remap |
| 用主机 qemu 首词否证板上 caption | runtime 不同 | 板上 greedy 才是内容门 |
| 把 float 头 skip 包当全 BPU TTS | 头仍在 CPU | 驻留独立 `lm_head` |
| 开放句糊就把 LLM/Euler 整网放到 ARM | 墙钟从百毫秒变数秒，且不修加速器图 | 重网络留加速器；CPU 只胶水 |
| Prefill-only 听感过就报产品 tok/s | 每步重灌 Prefill，墙钟 O(n)×Prefill | 速度 SKU 仍看 Decode T=1 |
| 量化估计器失败就重编整条 token2wav | 声码器可能已过门 | 拆 float/PTQ 交叉对照 |
| 把甲 SoC 官方 PPL 当乙 SoC 交付门 | SDK/march 不同 | 各芯片自己的任务门 |
| GPU 容器加载 PTQ ONNX 崩溃就当图坏 | 可能是容器 ABI | 换已验证 CPU 容器 |
| qemu 挂 Input Info 就重编 yaml | load/I/O 可能已过 | 先板上 device |
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
| 整仓安装地瓜 90+ skill 当本仓公理 | 与 IOVA/任务门冲突且抢上下文 | `rdk-official-catalog` 对照；按需打开官方原文 |

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
- [ ] 板端：加速器时间 + 墙钟 + 任务多指标；刷屏对照已静默且 ids 不变
- [ ] hop：图像间 cosine 门，而非仅 maxabs
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
- 地瓜官方 skill 对照：`rdk-official-catalog`
- 语义检测上板：`semantic-occupancy-fusion`
- 远端执行与取材：`remote-ssh-dev`
