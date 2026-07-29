---
name: edge-bpu-runtime-iova
description: >-
  Edge NPU/BPU multi-model runtime methodology for IOVA / IOMMU mapping failures,
  dual-HBM residual poison, load-order contracts, co-preload of peer AR segments,
  lifetime caching, core binding vs daemons (e.g. AltServer), mutex sessions, and
  when cold reboot is actually required. Use when loading multiple HBMs, seeing
  "iova addr not equal for different core", false "model corrupted", Talker-then-
  late-MTP, ASR/TTS handoff, Codec vs perception cores, dual hrt_ucp_monitor, or
  designing pipelines that share one SoC.
---

# 边缘加速器多模型运行时（IOVA / 加载序）

适用于同一 SoC 上加载多个加速器模型包（HBM / 分段图 / AR leap）时的运行时契约。  
目标：**按板上证据区分「单模可恢复 / 双模契约脆弱 / 真毒化须冷启」**，禁止把软件互斥文案写成硬件公理。

## 1. 问题定义

常见失败（日志常误导）：

- `iova addr not equal for different core`（可能打出 core_0↔core_1 或 core_0↔core_3）
- md5 不变仍报 `Hbm corrupted` / `libhbrt 需升级` → **次生文案**，不是文件坏了
- 兄弟段晚加载：推理过 A 再 load 本应同会话的 B（Talker→晚 MTP）
- 脏 boot 上**第二次** dual-load（enc+dec 或 dec+enc）失败；单模仍可能 OK
- 两存活进程并发握 leap HBM：一成一败或双败
- Codec@3 与常驻感知（AltServer/YOLO@0/1）映射冲突
- 软件锁 `poisoned=true` ≠「本 boot 任何 HBM 都载不了」

本 skill 管加载、绑核、同预载、生命周期、进程边界、毒化恢复；精度见 `horizon-bpu-ptq`，实验置信度见 `field-validation-method`。

## 2. 不变量 / 第一性原理

1. **IOVA 是设备侧共享运行时状态**（常与 `hrt_ucp_monitor` + `libdnn` 相关），不是纯进程私有页表。
2. **单 HBM**：同 boot 内 load → `del` → 再 load、进程 A 退出后进程 B 再 load，板上已多次证明 **OK**。
3. **多 HBM（dual-load）契约脆弱**：冷启后**第一次**齐套 preload 通常 OK；失败后的残留会话上，再 dual-load（无论 enc→dec 或 dec→enc）易 `iova addr not equal`；假 corrupted 是次生现象。
4. **Python `del` ≠ 已证实的 `hbDNNRelease`**：官方有 release API；`del` 是否等价未闭案。未完整释放时，单模可活、双模易死。
5. **兄弟段同预载**：同会话 peer（Talker+MTP、Enc+Dec）必须在**任一 peer 首次推理前**全部 load；禁止先推理 A 再晚载 B。
6. **核是预算**：感知常占 0/1；语音 AR@2；Codec/Decoder@3。抢核/多核校验失败 ≠「跑过 ASR 就必须 reboot」。
7. **冷启条件要写窄**：真毒化（连续假 corrupted / dual-load 已失败）、并发握锁打坏、Codec 在脏映射上怎么都 load 不上 → 请用户冷启。  
   **不要**仪式性「ASR 跑完 / 换管线就 reboot」。ASR 干净退出后 Talker/MTP@2 同 boot 再载已证 OK。
8. **Agent 禁止擅自 reboot**；加载门禁 ≠ 任务门禁（qcos/CER 另报）。

## 3. 架构 / 选型决策树

```text
要加载加速器 HBM？
  ├─ 单 HBM？
  │     → 通常可 load / del / 再 load；进程退出后再开新进程也常 OK
  ├─ 同进程 ≥2 HBM（enc+dec / Talker+MTP / Codec+AR）？
  │     ├─ 冷启后首次？ → 按契约齐套 preload，缓存到进程结束
  │     ├─ 本 boot 已出现过 dual-load IOVA 失败？ → 停测，请用户冷启（勿再赌 dual）
  │     └─ 未失败但要换管线？ → 前一进程干净退出后可换（Talker/MTP）；Codec 另查 0/1 daemon
  ├─ 两存活进程同时 load？ → 禁止（必踩并发 IOVA）
  └─ 与常驻 daemon 抢核（Codec vs AltServer）？
        → 先核预算；失败时勿归因成「ASR 用过」
```

| 模式 | 何时用 | 约束 |
|------|--------|------|
| 同进程齐套 preload + 缓存 | ASR enc+dec；TTS Codec→Talker+MTP | 推理前齐套；默认不中途 del/reload |
| 单模串行 | dump / 探针 | 单 HBM 可再载；勿升级成未契约的 dual |
| 分进程串行 handoff | ASR 评测完再 TTS AR | owner 退出且未 dual-失败残留 → Talker/MTP OK |
| 冷启恢复 | dual-load 已失败 / 连续假 corrupted / Codec 死锁映射 | 仅此时请用户 reboot |
| 重段优先 | Codec | 先 Codec；失败查双 `hrt_ucp_monitor` 与 0/1 占核 |

## 4. 标准操作流程 SOP

### 4.1 设计

1. 列出会话内全部 HBM 与角色、**core 预算表（含 daemon）**。
2. 写死 load order、同预载集合、lifetime。
3. API 单例缓存 + `ensure_*_stack()` 齐套入口。
4. 软件门禁（如 `bpu_session`）：拦**存活并发 owner**与 **poisoned**；允许干净退出后 pipeline 切换；Codec 失败文案点名 AltServer/多核映射。

### 4.2 冒烟（冷启后）

建议最小对照（角色主机 `<robot_host>`）：

1. 冷启 → 同进程 enc+dec preload（期望 OK）→ 推理 → 干净退出  
2. 新进程再 enc+dec（记录：OK 或 residual 失败）  
3. 若失败：尝试显式 `hbDNNRelease` 包装 vs 仅 `del`（未证前勿假设等价）  
4. 确认 `hrt_ucp_monitor` 是否应仅单实例；双实例要记入现场笔记  

禁止路径（文档化预期失败）：先单模推理再晚载兄弟段；两进程并发 dual-load。

### 4.3 评测

1. 毒化风险 stage：同进程开场齐套，或分进程且前一路干净退出。  
2. 禁止：encoder-only 后又 dual-load（除非 release/owner 已死）；Talker 推理后再 load MTP。  
3. 一现 dual-load IOVA / 连续假 corrupted → **停测**，请用户冷启；**禁止** scp 当修文件。

### 4.4 Agent 行为

- 当 IOVA / 假 corrupted，勿当坏 HBM 反复推包。  
- 「fresh_boot / 锁过期」≠ IOVA 干净。  
- 换管线：先看是否 poisoned / 是否有存活 owner；不要默认要 reboot。  
- **禁止**擅自 reboot。汇报：主机角色、核表、单/双模、是否毒化、是否待冷启。

## 5. 度量与门禁

| 类型 | 虚荣 | 验收 |
|------|------|------|
| 单模 | Runtime 构造成功 | load→del→reload 与跨进程再 load 仍 OK |
| 双模 | 第一次 preload OK | 契约路径连续推理无 IOVA；失败后不再盲试 dual |
| 同预载 | 「当前模式不用 peer」 | 同会话后续模式仍成功 |
| 切换 | 「必须冷启才能换 ASR/TTS」 | 干净退出后 Talker/MTP 可载；Codec 单独门禁 |
| 恢复 | kill 进程 / 推包 | 新进程单模可载 **或** 明确须冷启才能 dual |
| 任务 | 能出 wav/文本 | qcos/CER 与 IOVA **分列** |

## 6. 故障分类学（症状 → 原因 → 否证）

| 症状 | 更可能原因 | 否证 / 处置 |
|------|------------|-------------|
| 单 HBM load/del/reload OK | 正常 | 勿据此声称「整机未毒化可 dual」 |
| 同进程 enc→dec 或 dec→enc：`iova` / core_i≠core_j | 双模契约失败或残留会话 | 停 dual；冷启后再齐套 preload |
| 两进程并发 load decoder：一成一败 | 并发握锁 | 单 owner；等退出 |
| C 成功、B load MTP 失败 | **晚加载兄弟段** | 开场同预载 Talker+MTP |
| 工厂每次 `new Runtime` 第二次挂 | 未缓存 = 二次加载 | 进程内单例 |
| Codec `core_0↔core_3`，Talker@2 仍 OK | AltServer/感知占 0/1 + Codec 多核映射 | 查 daemon；勿归因「ASR 用过」 |
| `Hbm corrupted` 且 md5 不变 | 次生误报 | 冷启后同文件能 load 即证实 |
| 软件 `poisoned=true` 但单模仍能 load | 锁偏严 / 毒化≠全灭 | 单模探针可做；**dual 仍禁止**直至冷启 |
| 双 `hrt_ucp_monitor` 映射全部 `/dev/bpu` | 监控/运行时重复实例 | 记现象；冷启对照单实例 |
| ASR 评测后同 boot Talker/MTP OK | 干净 handoff | 允许；勿逼仪式 reboot |
| 13:xx 首次 dual 挂、同 boot 稍后/冷启后再跑通 | 脏映射 vs 干净 boot | 以是否出现过 dual 失败为准，不以「跑过 ASR」为准 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 「进程退出永不清 IOVA」一刀切 | 单模反例已足 | 分单模 / 双模 / 毒化残留 |
| 「ASR 跑完必须冷启才能 TTS」 | Talker/MTP 反例已足 | 看 poisoned 与存活 owner |
| 「换 pipeline = 硬件必须 reboot」 | 把软件策略当公理 | 门禁只拦并发与毒化 |
| C 省 MTP，跑到 B 再 load | 晚载兄弟段 | 开场齐套 |
| 每次 new Runtime / 模式结束 del+gc | 二次加载 / 释放不完整 | 单例常驻；release 未证前慎 del 后再 dual |
| 同 boot 两进程同时握 leap | 并发 IOVA | 一进程一 owner |
| corrupted → scp 重推 HBM | 掩盖映射问题 | md5 + 冷启对照 |
| Agent 代 reboot | 藏证据 | 请用户重启 |
| IOVA 过就宣称 freerun/精度达标 | 加载≠任务 | 分列门禁 |
| `poisoned` 后仍盲试 enc+dec | 加重残留 | 停 dual，冷启 |

## 8. 交付 / 复盘清单

- [ ] 模型列表、core 表（含 daemon）、load order、同预载集合、lifetime  
- [ ] 单模 vs 双模对照结论；并发对照  
- [ ] 禁止路径：晚载兄弟段；并发 dual；毒化后盲试 dual  
- [ ] 冷启条件写窄（毒化 / 并发打坏 / Codec 死映射）  
- [ ] `hrt_ucp_monitor` 实例数、是否尝试 `hbDNNRelease`（标明未证）  
- [ ] Agent 无自动 reboot；加载与精度分列汇报  

## 9. 相关 skills

- 量化：`horizon-bpu-ptq`  
- 实验方法：`field-validation-method`  
- 远端执行：`remote-ssh-dev`  
- 配置沉淀：`author-cursor-config` / `cursor-config-sync`
