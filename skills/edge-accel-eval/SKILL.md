---
name: edge-accel-eval
description: >-
  Deep on-device quality and speed evaluation after NPU/BPU quantization:
  model vs hardware vs software levers, roofline, multi-core vs sequential
  pipelines, and a complete markdown investigation report. Use when claiming
  board FPS, core_num speedup, utilization, latency, or task quality for a
  compiled accelerator package; when cores look idle; or when writing the
  post-PTQ eval report.
---

# 端侧加速器质量与速度深评

量化编译通过之后，必须在**真实部署机**把质量和速度拆开评，并落一篇完整调查报告。
编译器 latency、核数、sysfs 忙闲、单点 cosine **都不是**任务达标。跨领域实验环见 `field-validation-method`；编译门禁见 `horizon-bpu-ptq`；多包加载见 `edge-bpu-runtime-iova`。

## 1. 问题定义

上板后常见误判：

- 以为 `core_num=N` 应接近 N 倍墙钟
- 以为核「没吃满」就是没调度上
- 用服务 FPS 或端到端秒数当芯片算力
- 把 mix 包（重段已多核）和「全集单核」当成同一对照
- 质量只报校准余弦，速度只报一个平均数

本 skill 给出：**模型 / 硬件 / 软件三轴拆分、对照设计、门禁、报告模板**。

## 2. 不变量 / 第一性原理

1. **墙钟 ≠ 加速器时间 ≠ 阵列利用率**。主机预处理、H2D、DDR、段间隙都会进墙钟；MAC 空转等数也会进「有在跑」。
2. **多核是图划分，不是复制 N 份独立 worker**。核间 Recv/同步是开销；少绑会 abort，多绑不会把单核图再切开。
3. **只给算力墙升核**。搬数墙先减往返与常驻张量，不要默认全段多核。
4. **串行流水线服从阿姆达尔定律**。任意时刻只有一段在核上时，整体加速比被不能并行的部分钉死。
5. **独占核 + 记录频率**才是芯片能力；与相机 ISP、其它包争用时的墙钟是系统能力。
6. **同 feed 才可比质量**；速度对照必须锁定 iters、输入尺寸、常驻/逐段、LRU、是否独占。
7. **加载成功 ≠ 任务达标 ≠ 速度达标**。报告必须分列。

## 3. 架构 / 选型决策树

```text
要解释「慢 / 没吃满 / 多核没加速」？
  ├─ 先画调用图：几段、是否串行、每段迭代次数
  ├─ 列出每段 compile 核数 vs 绑定核列表（二者不同则先记下来）
  ├─ 独占加速器，分段打墙钟（段内 rt.run 前后）
  │     ├─ 某段墙钟随核数几乎不变 → 搬数墙（DDR / 每轮全量提交）
  │     ├─ 某段随核数亚线性升（如 ~2× 而非 N×） → 算力+带宽混合；看权重/激活体积
  │     └─ 某段接近编译器估计且随核数升 → 才是算力墙
  ├─ 对照包：全集单核 / 只重段多核 / 全段多核（一次只换一类变量）
  ├─ 质量：同 feed 任务指标 + 部署域 held-out；禁止只用校准余弦
  └─ 杠杆：核数只动算力墙段；iters/分辨率/改图/runtime 常驻输入分列验证
```

Roofline（单核是否「吃满」）：

- **算力密度低**（每字节 DRAM 摊不到足够 MAC）→ 单核也会空转
- **工作集大于片上 SRAM** → 反复打 DDR
- **算子不是密集 Conv/Gemm**（Norm / Softmax / Copy / Resize）→ 利用率上限低
- **主机在段间插入拷贝或 JPEG/HTTP** → 核上 ratio 被时间平均稀释
- **缓存池/allocator 泄漏** → 第 N 帧 OOM 或变慢，看起来像硬件病

## 4. 标准操作流程 SOP

1. **写 run_meta**：主机角色、包 stamp、核数表、iters、常驻或逐段、LRU 开关、是否独占、输入域。
2. **短冒烟**：能 load、能 finite 输出、无 IOVA/ION 硬故障。失败先按 `edge-bpu-runtime-iova` 软恢复，禁止为赶速度强载。
3. **质量门（独立于速度）**：同 feed 的任务多指标相对基线；calib ≠ held-out；相机流无 GT 时标明「链路通 ≠ 测距精度」。
4. **速度剖分（独占）**：
   - 分段墙钟（feat 类骨干 / 初始化 / 轻头 / 迭代体 ×N）
   - 迭代次数 1/2/N 是否线性（线性 → 迭代体是稳杠杆）
   - 编译器估计 vs 板端该段 `run()`（差距大 → 提交/DDR 税）
   - 单核全集 vs 只重段多核 vs 全段多核
   - **官方采集器（可选，分列）**：`hrt_model_exec perf`（thread/core 扫描）、`hb_analyzer`（带宽/利用率）、Perfetto `.pftrace`（调度空隙）、`hrt_ucp_monitor`/`hrut_ddr`（推理期资源）。高频监控不要走 gRPC `hbm_infer`。这些输出是线索，**不能**单独宣称芯片 FPS；仍须独占频率 + 分段 `run()` + 任务质量表。工具路径见 `rdk-official-catalog`。
   - **同一 `HB_HBMRuntime` 上的 Python 多线程**：墙钟不降、ratio 只在一个核，是排队，不是四核图。`perf --thread_num 4` 可以让多个核出现 ratio，它的 FPS 仍是工具帧率。`core_num=1` 不会因为线程数变成多核图。四个实例的墙钟接近串行时，不要写成四倍吞吐；没采 ION 就不能断定是一份权重还是四份。
   - **同一条请求里的多段**：视觉和 Prefill 同时提交时，墙钟可以靠近较重的那段。Decode 与任何一段同时提交时，墙钟相加，Decode 步会被拉长。生成过程中不要插入下一段。四份独立图的工具帧率不到四倍、单步更慢时，仍分列单线程质量和工具吞吐。
5. **硬件快照**：活测 DRAM Available、进程 RSS、**持包那块 ION 堆**、各核 busy/ratio、温度。禁止把 DRAM 标成「通常不是瓶颈」，禁止 DRAM+ION 相加。长跑、切分、演示 Web 见 `edge-board-system-test`。官方 `rdk-diagnostic` / `rdk-memory-audit` 只读脚本可用。
6. **软件契约**：`input_source`、Python 是否每 `run()` 全量 DDR 提交、LRU 是否跨帧吞堆、绑定核是否大于编译核。
7. **SKU 结论**：速度默认包可以是「只重段多核」；全段多核若墙钟无差且堆更肥，不要当速度基线。
8. **落盘完整 md**（模板见 §8）。改进计划按 `edge-accel-improve` 只选一层杠杆。
9. 链到 `docs/investigations/` 与 `PROJECT_STATE.md`。原始 JSON 放 `<data_root>/eval/<TASK>/`。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| 编译器 FPS / latency | 独占板上分段墙钟 + 端到端 |
| `core_num=N` | 相对**全集单核**的段表；写清加速比分子分母 |
| sysfs 平均 ratio 低 | 先分段峰值；再判带宽墙 vs 空窗 |
| 服务 FPS（含 HTTP/JPEG） | 另列「纯推理 e2e」与「服务 e2e」 |
| 校准节点 cosine | 任务指标（EPE/CER/mAP 等）+ held-out |
| `hrt_model_exec` 峰值 FPS / 官方 cosine 0.99 | 独占分段 `run()` + held-out 任务 |
| Python 四线程墙钟或 `perf --thread_num` FPS | 单线程质量列与工具吞吐列分开；`core_num=1` 仍是一张图 |
| 一次 mix 切全多核几乎没变 | 查重段是否已经是多核（对照选错） |

通过：报告同时有质量表、分段速度表、三轴归因、下一步单一杠杆。缺表不得宣称「多核没用」或「已经吃满」。

## 6. 故障分类学

| 症状 | 可能原因 | 否证 |
|------|----------|------|
| 全段多核 ≈ 只重段多核 | 轻段本就是搬数墙或占比小 | 段表；iters 扫描 |
| 多核 Feat 类段只有 ~2× | 带宽墙 / 切分不均 | 权重体积；编译估计 vs 板端 |
| 迭代段与核数无关 | 每轮全量 DDR 提交大张量 | 迭代 1/2/N 是否线性加同一常数 |
| 核 ratio ~25% | 时间平均含段间隙+等 DDR；或单核图被多绑摊到多核 | 单段峰值；对齐 compile 核数再绑 |
| 第 3 帧 ION 失败 | 运行时缓存池跨帧不归还 | 关缓存后堆是否平坦 |
| 服务慢、纯 run 不慢 | 预处理/编码/拉流 | 合成张量 vs 相机路径对照 |
| 单核大包 load 失败 | 加速器堆小于整块权重 | 读 heap total；勿当成文件损坏 |

## 7. 反模式与理由

| 本能 | 为何失败 | 正确做法 |
|------|----------|----------|
| 「N 核应该 N 倍」 | 忽略串行、切分、带宽 | 段表 + 阿姆达尔 |
| 用 mix 当单核基线 | 重段已多核，差值被吃掉 | 必须有全集单核对照 |
| 平均利用率当调度失败 | 带宽墙时 MAC 本来就不满 | Roofline；看峰值与段对齐 |
| 为提速全段升核 | 搬数段零收益、ION 更肥 | 只升算力墙段 |
| 为提速改量化配方 | 打回 CPU/毁精度 | 配方冻结；动核数/图/iters/runtime |
| 不写报告只口播 | 下轮重复测、对照丢失 | §8 调查 md |
| qemu 多核挂死当板慢 | 主机仿真不是板端墙钟 | 板上 device |
| 官方 perf 开 LRU 当默认 | 跨帧池可吞 ION | 对照开关；记 heap |

## 8. 交付：完整调查报告模板

路径：`<project_root>/docs/investigations/YYYY-MM-DD-<task>-accel-eval.md`
编码：UTF-8 无 BOM，写完走 `utf8-chinese-docs`。禁止 IP、凭据、私有绝对路径。

```markdown
# <任务> 端侧质量与速度深评（YYYY-MM-DD）

## 元数据
- 主机角色、时间窗、是否独占加速器
- 包 stamp / 核数表 / iters / 常驻或逐段 / 缓存开关
- 输入：合成张量 vs 相机/文件；尺寸与预处理

## 质量（与速度分列）
- 同 feed 任务指标 vs 基线；held-out 是否与 calib 相交
- 无 GT 时明确：链路通 / 有限输出 ≠ 精度门

## 速度剖分
- 段表：全集单核 | 只重段多核 | 全段多核
- 迭代 1/2/N 的 e2e
- 编译器估计 vs 板端该段
- 纯推理 e2e vs 服务 e2e

## 三轴归因
- 模型：串行段、迭代体、分辨率/骨干、切分是否算力墙
- 硬件：堆头寸、带宽 vs MAC、温度、争用
- 软件：提交契约、绑定 vs 编译核、缓存泄漏、主机税

## 结论与 SKU
- 速度默认包 / 质量默认包（可不同）
- 确证 | 强推断 | 待证

## 下一步（只写一个主杠杆，层号见 `edge-accel-improve`）
## 证据路径
```

原始采样 JSON 不进 git 公共仓时可放 `<data_root>/eval/<TASK>/`。

## 9. 相关

- `horizon-bpu-ptq` / `bpu-quantize`：编译与精度门禁
- `edge-accel-improve`：评完如何按层提速/提质
- `edge-board-system-test`：长跑 hwmon、内存切分、板端体验面
- `edge-bpu-runtime-iova` / `bpu-iova-runtime`：多包加载
- `field-validation-method`：O-H-V-C
- `remote-ssh-dev`：板上执行与取材
- `rdk-official-catalog`：地瓜 `hrt_model_exec` / analyzer / Perfetto 对照
- `project-continuity`：调查与状态文件
- `privacy-github` / `utf8-chinese-docs`
