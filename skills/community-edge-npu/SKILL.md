---
name: community-edge-npu
description: >-
  Evaluate third-party on-device NPU/BPU runtimes and conversion zoos that wrap
  a vendor driver rather than the vendor org. Use when seeing independent
  GitHub users shipping HBM or session APIs for the same SoC, BLLM/BCDL-class
  wrappers, community model zoos, low-star same-chip projects missed by
  official-org watchlists, or when choosing native hbDNN versus a vendor LLM
  SDK. Do not treat their FPS or recipes as on-device acceptance.
---

# 同芯社区运行时与配方仓

厂商组织仓不是同芯片上唯一有用的开源。失败模式是：早报只扫官方 org / star 榜，把「独立作者、同一 SoC、已出 `.hbm` + 板上门禁」漏掉；或者反过来把社区 README 的 tok/s 抄成产品芯片能力。

短例（不是公理）：[ruisv/bllm](https://github.com/ruisv/bllm) 把会话/采样/混合 SSM 解码建在通用 `hbDNN`/`hbUCP` 上；[ruisv/bcdl](https://github.com/ruisv/bcdl) 做视觉零拷贝与后处理。转换在对应 `*-model-zoo`。

## 1. 问题定义

社区仓解决的是：**官方示例级运行时之上的产品层**（目录约定、停止符、KV/SSM、后处理、与视觉抢核），以及官方工具链尚未覆盖的图（例如混合 Gated-DeltaNet）。
本 skill 解决的是：**如何发现、对照、试用建议，而不把第三方配方写成现场门禁**。

## 2. 不变量

1. **同芯 > 同名 > star 数**。未上该 SoC、只改名的 CUDA/TRT/RKNN 仓默认忽略。
2. **社区封装 ≠ 厂商 LLM SDK ≠ 本仓 leap 图**。三者可以吃同一份 `.hbm`，也可以是完全不同的图与 ABI。未做同 feed 对照前禁止替换产品路径。
3. **两套运行时默认不同会话**。厂商 `libxlm`/OE-LLM 与社区 `hbDNN` 封装不要默认同进程双持有；IOVA 仍走 `edge-bpu-runtime-iova`。
4. **编译干净会撒谎**。错校准域、头内 `ScatterND` 锚点解码、错 eos / mrope，都能 link 并全速跑，再静默毁掉任务。
5. **cosine 不是 LLM/VLA/ReID 门**。LLM 要 Prefill↔Decode  parity、held-out PPL、任务锚；VLA 要动作幅度 `‖a‖/‖a_ref‖` 加同一 harness 的参考列；ReID 要 Rank-1。
6. **`cal_data_type=float32` 时编译器 `norm_type` 往往不作用在校准集上**。校准必须预归一化到运行时分布。
7. **多核改调度不改算术**。社区「按图混核、输出逐位相同」与本仓 `core_num=N` 不是 N 倍墙钟一致；只给算力墙升核。
8. **权重许可 ≠ 仓许可**。`.hbm` 是权重衍生品；AGPL / NC 数据集 / 未声明训练数据禁止当可再分发交付。
9. **私有 `host_toolchain` / leap 构图未公开 ≠ 不可用运行时**。公开的是验收与配置；不要把未公开构图抄进本仓。
10. **社区 tok/s、LIBERO 分数、1080p 流水线 FPS 是作者板上数字**，独占、频率、march 未知时只当线索。验收仍走 `edge-accel-eval`。

## 3. 决策树

```text
发现同芯片社区仓？
  ├─ 不是本 SoC / 只是 TRT·RKNN·云端 → 忽略（方法可记一句）
  ├─ 只是 demo 换皮、无板上门禁 → 忽略
  ├─ 视觉后处理 / 零拷贝 / 校准卫生 / 静默坏图
  │     → 对照门禁：吸收分类，不覆盖已过门 YAML
  ├─ 官方未覆盖的架构（混合 SSM、VLA 策略图）
  │     → 跟踪：读 zoo 的 rejected_builds 与 expected.json
  │     → 试用须用户确认；与产品 leap/OE-LLM 做同 feed 双路径
  └─ 要换产品运行时？
        → 先 IOVA 契约 + 同 feed 任务门；禁止「conda 能 chat 就算切换成功」
```

早报漏检：把「高认可」定义成官方 org。正确门是 **同芯 + 同任务 + 可核对的板上记录**。

## 4. SOP

1. **发现**（不克隆、不镜像）
   只读 `watchlist.yaml` 会漏尚未登记的作者。存量必须再跑情报树 `--mode discover`（`search-net.yaml` 的 hbDNN/nash/hbm 指纹）。unknown 用 hit-card 标注后才允许追加 watchlist。论坛帖只作入口，数字以 GitHub/HF 为准。

2. **分层读**
   README 声明的架构覆盖 → `CHANGELOG` 的 breaking（L2M 预算、混核）→ zoo 的 `expected.json` / `rejected_builds` → 许可表。不要先下 GB 级包。

3. **对照本仓**
   | 社区声称 | 本仓怎么用 |
   |---|---|
   | 通用 hbDNN 上跑官方 `.hbm` | 服务化/停止符/前缀缓存的对照，不改量化 |
   | 混合 SSM 100% BPU | 与 leap 分段对照，禁止把作者 tok/s 写入 VELA 门 |
   | LAS2 双目 | 不是 FoundationStereo；立体主线不自动换模型 |
   | π0.5 / SmolVLA | 与 InternNav DualVLN 不同栈；未点名 VLA 策略则只跟踪 |
   | PointPillars 1×1 改写、OSNet QAT | 布局墙 / 任务指标的分类，按任务试用 |

4. **试用（须用户确认）**
   独立会话；不与产品 OE-LLM 同握；Release；记录 march（`nash-e`/`nash-m`/`nash-p`）与核绑定。`试用` ≠ 开编、≠ 覆盖交付。

5. **吸收**
   只升级本仓门禁分类（校准域、静默坏图、LLM/VLA 门）。禁止把社区 `config.yaml` 整份粘进 TASK。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| star、论坛热度、conda 能 `import` | 同芯、有板上记录、能映射本仓元素 |
| 作者 tok/s / 441 FPS | 独占分段 `run()` + 任务指标（`edge-accel-eval`） |
| 视觉 cosine≥0.99 | 有任务指标时用任务指标；ReID/光流/VLA 尤其如此 |
| 「无需 OE-LLM SDK」 | ABI/IOVA/ION 与产品路径的对照实验 |

## 6. 故障分类

| 症状 | 原因 | 否证 |
|------|------|------|
| 早报空档但漏掉同芯仓 | 只扫官方 org 或只扫已登记仓 | watchlist 之外是否跑过 discover 指纹 |
| 两套 runtime 同崩 | 双持有 / 双 ABI | 单会话单栈是否恢复 |
| 编译成功任务崩 | 校准未预归一化、头未切开、错 eos | `rejected_builds` 与同 feed |
| 抄社区 4 核 tok/s | 把作者板当本仓公理 | 本仓独占测量 |
| 把 LAS2 当 FoundationStereo | 同任务不同权重 | 模型卡与图结构 |
| 多核 Get memspace 失败 | L2M/`max_l2m_size` 预算而非硬件 | 单核同图是否 load |

## 7. 反模式

| 做法 | 为何失败 | 正确做法 |
|------|----------|----------|
| 只扫 D-Robotics org | 漏掉同芯产品层 | P1 社区 runtime + zoo + discover 指纹 |
| 整仓镜像社区 skill/conda | 抢上下文、双 ABI、许可不清 | 链接 + 分类吸收 |
| 用社区包覆盖 leap 交付 | 图与验收不同 | 双路径，用户确认才切 |
| 无参考列的策略分 | 把 checkpoint 天花板读成移植失败 | 同 harness 打参考 |
| 再分发 NC/AGPL `.hbm` | 仓 MIT/Apache 救不了权重 | 跟 zoo 许可表 |
| 把聊天/VLM zoo 当语音 CFM/估计器/ASR 配方 | zoo 覆盖会话图，不是 Euler/HiFT/Paraformer | 对照本仓调用图与公开目录；缺口自建 TASK |
| 把 Omni 2s 音频塔当听写 CER | 聊天条件嵌入 ≠ 识别解码器 | ASR 用识别图与 CER 门 |

## 8. 交付清单

- [ ] 已判断同芯 / 同任务 / 许可
- [ ] 未把作者 FPS 写入芯片能力
- [ ] 未默认同会话混 OE-LLM 与社区封装
- [ ] 可吸收的是门禁分类，不是 YAML 整页
- [ ] 早报/存量渠道已能扫到该类仓（watchlist + discover，`industry-watch`）

## 9. 相关

- 官方命令：`rdk-official-catalog`（冲突时现场门禁优先）
- 量化与图：`horizon-bpu-ptq`
- 加载释放：`edge-bpu-runtime-iova`
- 板上数字：`edge-accel-eval`
- 早报渠道：`industry-watch`
- 实验环：`field-validation-method`
