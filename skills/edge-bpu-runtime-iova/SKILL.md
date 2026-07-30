---
name: edge-bpu-runtime-iova
description: >-
  Edge NPU/BPU multi-model IOVA methodology: accelerator-package load/release
  contracts, sibling peer co-preload, sticky asymmetric order (including
  cross-pipeline handoff), one-primary-pipeline-per-boot for eval, session-end
  release, soft recover without reboot, and when cold reboot is required. Use
  when seeing "iova addr not equal", false "model corrupted", multi-HBM handoff,
  concurrent holders, ASR↔TTS-like pipeline switches, or designing pipelines
  that share one SoC map.
---

# 边缘加速器多模型运行时（IOVA / 加载·释放）

同一 SoC 上多个加速器模型包（静态图 / leap 分段 / 多 HBM）共享 **host↔per-core IOVA 表**。  
目标：区分 **单模 / 双模契约 / 粘滞毒化 / 跨管线不对称 handoff / 可软恢复**，给出可跨项目复用的加载·释放规范。

## 1. 问题定义

- `iova addr not equal for different core`（日志可能点名任意 core_i↔core_j）
- 伴随假文案 `Hbm corrupted` / `libhbrt 需升级` → **包文件未必坏**，勿当修文件反复推包
- 兄弟段晚载、并发双持有、粘滞后 **某一加载序** 失效
- **跨管线**：A Release 后载 B 失败，而 B Release 后载 A 仍成功（方向不对称）
- 软件会话锁 `poisoned` ≠ 硬件已死；单模往往仍可载——**不能**因此 bypass 强测 dual

精度门禁见 `horizon-bpu-ptq`；实验方法见 `field-validation-method`。

## 2. 不变量 / 第一性原理

1. IOVA 是 **设备侧共享状态**（厂商 DNN/HBRT 栈；常与 UCP monitor 相关），不是进程私有页表。
2. **有 per-handle 释放**（如 `hbDNNRelease`；Python 侧 `del` Runtime + `gc` 走析构）。**无**可靠的全局 IOVA flush 接口时，勿幻想「一键清表」。
3. **会话内**：同会话 peer 必须在任一 peer **首次推理前**齐套 preload；禁止推理后再晚载兄弟段。
4. **会话结束必须 Release**。把「永不卸载、绑到冷启」写成默认策略是反模式。
5. **粘滞不对称有两层**：
   - **同管线 peer 序**（A→B vs B→A）
   - **跨管线方向**（管线甲→乙 vs 乙→甲）。**一侧实锤 ≠ 另一侧成立**。
6. **冷启写窄但仍要果断**：双序 dual 全死、跨管线所需方向未验证且评测需要、或与常驻 daemon 死锁映射 → 请用户冷启。Agent **禁止擅自 reboot**。
7. **poison 锁是硬停**：bypass/force 只允许探针/诊断，**禁止**当作评测默认。
8. 加载成功 ≠ 任务达标（精度/时延另报）。

## 3. 架构 / 选型决策树

```text
要加载加速器模型包？
  ├─ 单模？ → load → 用完 Release；可再 load；跨进程再 load 通常 OK
  ├─ 同会话 ≥2 包（兄弟 leap / 编解码 peer / AR+解码段）？
  │     → 推理前按契约齐套；结束 Release
  │     → 多段时：先齐套 AR/leap peer，再按需加载独立解码段（或解码段单独会话）
  │     → 若序 A→B 失败而 B→A 成功：判 sticky_asym，锁定 B→A
  ├─ 要换到另一条产品管线（如识别↔合成）？
  │     → 前一路已 Release 且未 poison？
  │           ├─ 目标方向已板上实锤？ → 允许 handoff，仍先单模/双模探针
  │           ├─ 仅反向实锤 / 未测？ → 评测默认「一 boot 一主管线」；要换向则请用户冷启
  │           └─ 已 poison？ → 停测，请用户冷启（禁止 force）
  ├─ 两存活进程同时握 leap/双模？ → 禁止
  └─ 已粘滞？
        → 软恢复探针（单模 / 双序 dual / 跨管线双方向）
        → 仍无可用 dual → 请用户冷启（勿推包）
```

| 模式 | 何时 | 约束 |
|------|------|------|
| 齐套 preload + 会话缓存 | 多 HBM 同会话 | 推理前齐套；结束 Release |
| 探针锁定加载序 | 默认与粘滞软恢复 | 以板上双序/双向对照为准 |
| 单模串行 | dump / 探针 | 可再载；勿盲升 dual |
| 分进程 handoff | 管线切换 | 仅 **已实锤方向**；否则一 boot 一管线 |
| 冷启 | 双序 dual 全死 / 未验证方向又必需 / 解码段死映射 / poison | 请用户 reboot |

**短例（语音双管线，可迁移）**：同 SoC 上「识别栈」与「合成栈」常共享 AR 核与解码核。板上曾实锤：识别干净退出 → 合成 AR peer 常可再载；**合成（含独立解码段）Release → 识别 dual** 仍可在 enc 成功后于第二段失败。评测排期：**一 boot 只主测一条**；需要另一条则冷启。

## 4. SOP

### 4.1 加载

1. 列出会话内全部模型包 + **core 预算**（含常驻感知/视觉 daemon 占用的核）。
2. 同会话 peer：一次性齐套；独立解码段可单独会话，或在 AR peer 齐套后再载。
3. 进程内单例缓存；统一 `ensure_*_stack()` 入口。
4. **禁止**：先推理再晚载 peer；两进程并发 dual；会话结束不 Release。

### 4.2 释放

1. 会话/请求结束：显式 Release（`close()` / `del`+`gc` / C API）。
2. 干净段上：dual → Release 双方 → 再 dual，应作为回归门禁。
3. 强杀持有进程后下一进程常可再 dual（干净段）；不作常规运维路径。
4. 部分释放某一 peer 再 reload：干净段或许可行；**推理后晚载**仍是主毒化路径。

### 4.3 跨管线 handoff

1. 查会话锁：`poisoned` → **停**；`fresh_boot` / boot 标识变化 → 当新表。
2. 查证据表：目标方向是否已实锤。未写进契约的方向 = 未验证。
3. 评测默认：**一 boot 一主管线**（先跑今天要验收的那条）。
4. 若必须同 boot 换向：先单模探针，再目标管线 dual 探针；任一失败 → 请用户冷启，勿连环 bypass。
5. Agent 文案禁止写「ASR↔TTS 双向都不用 reboot」这类对称结论。

### 4.4 软恢复（不重启）

1. 结束/杀掉残留持有进程；清过期软件锁（boot 标识不一致 / owner 已死）。
2. 探针：单模；peer 双序 dual；**跨管线两个方向分别**试（记 sticky_asym）。
3. 仅一序/一方向可用 → 锁定该路径继续；不要猜对称。
4. 关键 dual 均失败或 poison → **请用户冷启**。禁止把推包当 IOVA 修复。
5. `SPEECH_BPU_SESSION_BYPASS` / `--force-on-poisoned-boot`：**仅诊断**，默认评测关闭。

### 4.5 Agent

- IOVA / 假 corrupted → 按故障表，不推包、不擅自 reboot。
- 用户刚冷启且目标含多管线：先问/先排 **主管线**，不要为了「顺便」跑反向。
- 管线切换：先 Release，再按 **已实锤方向** 加载；反向未证则请冷启。
- 汇报：主机角色、加载序、单/双、跨管线方向、是否 sticky_asym、是否待冷启。

## 5. 度量与门禁

| 类型 | 虚荣 | 验收 |
|------|------|------|
| 单模 | 构造成功 | load→Release→reload；跨进程再 load |
| 双模 | 第一次 preload | 契约序连续推理无 IOVA；粘滞下至少一序可用 |
| 释放 | 调用了 close | 下一会话能按 **已证方向** dual |
| 跨管线 | 「Release 了」 | 两个方向分别记录 pass/fail；未测方向不算 pass |
| 恢复 | 清锁/杀进程 | 探针给出可用序/方向；或明确须冷启 |
| 任务 | 有输出 | 精度/时延与 IOVA 分列 |

## 6. 故障分类学

| 症状 | 更可能原因 | 处置 |
|------|------------|------|
| 单模 OK、仅一序 dual OK | 同管线 sticky_asym | 锁定存活序 |
| 甲→乙 FAIL、乙→甲 OK | **跨管线** sticky_asym | 一 boot 一管线；或只走存活方向 |
| 前序 peer 全 Release，换管线时第二段 HBM FAIL（第一段 OK） | 解码核/映射粘滞 | 勿归因文件损坏；冷启或改排期 |
| 先载独立解码段再齐套 AR peer 失败 | 粘滞 + 占表顺序 | AR peer 先于解码段；或解码段单独会话 |
| 推理 A 后晚载 peer B | 晚载兄弟段 | 开场齐套；已中招→探针序或冷启 |
| 并发第二进程 load | 双持有 | 单 owner；杀残留 |
| corrupted 且校验未变 | 次生误报 | 按 IOVA 处理 |
| poison 后 bypass 偶发「能跑」 | 假恢复 | 结果不作验收；仍须冷启再正式测 |
| 双序 dual 全 FAIL | 真粘滞 | 请用户冷启 |
| 日志总打到感知常占核 | daemon 占核冲突 | 闲置/停感知再测；勿归因成「换过管线」 |

## 7. 反模式

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| 永不 Release / 绑到 reboot | 叠映射→粘滞 | 会话结束必 Release |
| 死绑单一产品加载序 | 粘滞后可能恰好是死序 | 双序探针 + 锁定存活序 |
| 把单向 handoff 写成双向公理 | 反向未证却排进同 boot | 方向分列证据；一 boot 一管线 |
| 推理后晚载 peer | 主毒化路径 | 开场齐套 |
| corrupted → 重推模型包 | 掩盖映射问题 | 校验 + 序/释放/冷启 |
| poison 后 force/bypass 赶评测 | 污染结论、加深粘滞 | 停测；请用户冷启 |
| 「顺便」同 boot 跑反向管线 | 高概率第二段 IOVA | 另一次冷启专跑 |
| Agent 代 reboot | 藏证据 | 请用户重启 |
| 并发 dual | IOVA | 互斥会话 |

## 8. 交付清单

- [ ] core 表（含 daemon）+ 契约加载序（含 sticky 回退序）
- [ ] **跨管线方向证据表**（甲→乙 / 乙→甲 分列；未测标明）
- [ ] 评测排期：一 boot 一主管线
- [ ] 会话结束 Release；入口保证释放
- [ ] 软恢复探针与 sticky_asym（含跨管线）处理
- [ ] poison → 停测；无评测向 bypass；无自动 reboot；加载≠精度

## 9. 相关

- `horizon-bpu-ptq` / `field-validation-method` / `remote-ssh-dev`
- `author-cursor-config` / `cursor-config-sync`
