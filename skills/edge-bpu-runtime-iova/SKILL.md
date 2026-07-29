---
name: edge-bpu-runtime-iova
description: >-
  Edge NPU/BPU multi-model IOVA methodology: HBM load/release contracts,
  peer co-preload order (MTP-before-Talker), session-end hbDNNRelease, sticky
  asymmetric dual poison, soft recover without reboot, and when cold reboot is
  required. Use when seeing "iova addr not equal", false "Hbm corrupted",
  ASR/TTS handoff, Talker/MTP/Codec load failures, concurrent holders, or
  designing pipelines that share one SoC accelerator map.
---

# 边缘加速器多模型运行时（IOVA / 加载·释放）

同一 SoC 上多个加速器模型包（HBM / leap AR 分段）共享 **host↔per-core IOVA 表**。  
目标：用板上对照区分 **单模 / 双模契约 / 粘滞毒化 / 可软恢复**，给出统一加载·释放规范。

## 1. 问题定义

- `iova addr not equal for different core`（常见 core_0↔core_2/3）
- 伴随假文案 `Hbm corrupted` / `libhbrt 需升级` → **文件没坏**，勿 scp 重推
- 兄弟段晚载（先推理 A 再 load B）、并发双持有、粘滞后 Talker→MTP 失败
- 软件 `poisoned` 锁 ≠ 硬件已死；单模往往仍可载

精度门禁见 `horizon-bpu-ptq`；实验方法见 `field-validation-method`。

## 2. 不变量 / 第一性原理

1. IOVA 是 **设备侧共享状态**（`libdnn` / HBRT / 常与 `hrt_ucp_monitor` 相关），不是进程私有页表。
2. **有 per-handle 释放**：`hbDNNRelease`；Python `del Runtime` + `gc` 会走析构释放。  
   **无**全局 IOVA flush sysfs。
3. **会话内**：peer 必须在任一 peer **首次推理前**齐套 preload；禁止推理后再晚载兄弟段。
4. **会话结束必须 Release**（`close()` / `del`+`gc` / 显式 `hbDNNRelease`）。「永不清、绑到 reboot」是反模式。
5. **加载序在粘滞后不对称**：冷启 Talker↔MTP 双向通常 OK；粘滞后 **MTP→Talker 仍可、Talker→MTP 常死**。规范默认 **MTP→Talker→Codec**。
6. **冷启写窄**：仅当 MTP→Talker 与 ASR dual **都**不可用、或 Codec 死锁映射时请用户冷启。Agent **禁止擅自 reboot**。
7. 加载成功 ≠ 任务达标（qcos/CER 另报）。

## 3. 架构 / 选型决策树

```text
要加载 HBM？
  ├─ 单模？ → load → 用完 Release；可 del/reload；跨进程再 load 通常 OK
  ├─ TTS AR（Talker+MTP±Codec）？
  │     → 默认序：MTP@2 → Talker@2 → Codec@3（Codec 可单独用于 path A）
  │     → 推理前齐套；会话结束 close()
  │     → 若 Talker→MTP 失败但 MTP→Talker OK：判 sticky_asym，固定 MTP 优先
  ├─ ASR（Enc+Dec）？ → preload Enc@2+Dec@3（Dec→Enc 亦曾 OK）→ 结束 Release
  ├─ 两存活进程同时握 leap？ → 禁止
  └─ 已粘滞？
        → 先 bpu_soft_recover / MTP→Talker 探针
        → 仍双败 → 请用户冷启（勿推包）
```

| 模式 | 何时 | 约束 |
|------|------|------|
| 齐套 preload + 会话缓存 | ASR / TTS AR | 推理前齐套；结束 Release |
| MTP→Talker→Codec | TTS 默认 / 粘滞软恢复 | 勿 Codec→MTP→Talker（粘滞下易挂 Talker） |
| 单模串行 | dump / 探针 | 可再载；勿盲升 dual |
| 分进程 handoff | ASR 完再 TTS | 前一路 close/退出且未双死 |
| 冷启 | 双序 dual 全死 / Codec 死映射 | 仅此时 reboot |

## 4. SOP

### 4.1 加载（统一契约）

1. 列会话内全部 HBM + core 预算（感知常占 0/1；语音 AR@2；Codec/Dec@3）。
2. TTS：`MTP → Talker →（需要时）Codec`；ASR：`Enc → Dec`（或经探针的等价齐套）。
3. 进程内单例缓存；`ensure_*_stack()` 一次齐套。
4. **禁止**：先推理再晚载 peer；两进程并发 dual；会话结束不 Release。

### 4.2 释放

1. 会话/请求结束：`pipeline.close()` → `del rt` + `gc.collect()`（≡ 走 `hbDNNRelease`）。
2. 可用 C `hbDNNRelease` 做对照；干净段上 dual→Release 双方→再 dual **OK**。
3. `kill -9` 持有者后，下一进程常可再 dual（干净段）；仍应避免作为常规路径。
4. 部分释放一个 peer 再 reload：干净段曾 OK；**推理后晚载**仍是毒化主路径。

### 4.3 软恢复（不重启）

1. 杀残留 speech 持有进程；清过期 `bpu_session` 锁（boot_id 不一致 / owner 死）。
2. 跑 `scripts/bpu_soft_recover.py`：看 `mtp_then_talker` / `talker_then_mtp` / `asr_dual`。
3. `sticky_talker_first_asym=true` → 固定 MTP 优先，继续干活。
4. 两者 dual 都失败 → **请用户冷启**。禁止 scp HBM 当修复。

### 4.4 Agent

- IOVA / 假 corrupted → 按故障表，不推包。
- 换 ASR↔TTS：先 Release/退出，再按契约加载；不默认 reboot。
- 汇报：主机角色、序、单/双、是否 sticky_asym、是否待冷启。

## 5. 度量与门禁

| 类型 | 虚荣 | 验收 |
|------|------|------|
| 单模 | 构造成功 | load→Release→reload；跨进程再 load |
| 双模 | 第一次 preload | 契约序连续推理无 IOVA；粘滞下 MTP→Talker 可用 |
| 释放 | 调了 close | 下一会话能按契约 dual |
| 恢复 | kill/清锁 | soft_recover 诊断 + 可用序；或明确须冷启 |
| 任务 | 出 wav/文本 | qcos/CER 与 IOVA 分列 |

## 6. 故障分类学

| 症状 | 原因 | 处置 |
|------|------|------|
| 单模 OK、Talker→MTP FAIL、MTP→Talker OK | 粘滞不对称 | 固定 MTP→Talker→Codec |
| Codec→MTP→Talker 挂 Talker | 粘滞 + Codec 先占表 | AR 先于 Codec；Codec 单独 path A |
| 推理 Talker 后晚载 MTP | 晚载兄弟段 | 开场齐套；已中招→软恢复序或冷启 |
| 并发第二进程 load | 双持有 | 单 owner；杀残留 |
| `Hbm corrupted` md5 不变 | 次生误报 | 按 IOVA 处理 |
| ASR dual OK、TTS dual 粘滞 | 毒化局部 | TTS 用 MTP 优先；ASR 可继续 |
| 双序 dual 全 FAIL | 真粘滞 | 请用户冷启 |
| core_0↔core_N + 感知 daemon | AltServer/YOLO@0/1 | 停/闲置感知再测；勿归因「跑过 ASR」 |

## 7. 反模式

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 永不 Release / 绑到 reboot | 叠映射→粘滞 | 会话结束必 Release |
| 默认 Talker→MTP | 粘滞后易死 | 默认 MTP→Talker |
| 先 Codec 再 AR（当唯一序） | 粘滞下 Talker 易挂 | AR 齐套后再 Codec |
| 推理后晚载 peer | 主毒化路径 | 开场齐套 |
| corrupted → scp | 掩盖映射问题 | md5 + 序/释放/冷启 |
| Agent 代 reboot | 藏证据 | 请用户重启 |
| 并发 dual | IOVA | 互斥会话 |

## 8. 交付清单

- [ ] core 表 + 默认加载序（MTP→Talker→Codec / Enc→Dec）
- [ ] 会话结束 Release；入口 try/finally close
- [ ] soft_recover 探针与 sticky_asym 处理
- [ ] 冷启条件写窄；无自动 reboot；加载≠精度

## 9. 相关

- `horizon-bpu-ptq` / `field-validation-method` / `remote-ssh-dev`
- `author-cursor-config` / `cursor-config-sync`
