---
name: edge-board-system-test
description: >-
  On-device system validation after accelerator packages exist: co-preload,
  task smoke, timed soak with DRAM/ION/RSS/BPU sampling, memory-split
  decisions, and a board demo service. Use when claiming OOM-safe, reallocating
  CPU DRAM vs ION/carveout, running a 10-minute multimodal soak, or exposing
  full vision-language capability on a board web UI.
---

# 端侧系统验收（压测 + 资源切分 + 板端体验）

量化编译和单次深评之后，还要把**长跑、内存账、可演示服务**当成独立门。质量/速度剖分见 `edge-accel-eval`；多包加载见 `edge-bpu-runtime-iova`；实验环见 `field-validation-method`。

## 1. 问题定义

上板后常见误判：

- 用 `MemTotal`「大约 2G」当加速器堆，或把 ION 加进 Linux DRAM
- 用 VmPeak / HBM 文件体积当 RSS，宣称要 OOM
- 压测只记任务句和 TTFT，没有 1 Hz 硬件序列，却去改 CMA/ION 切分
- debugfs ION 把「last known client」历史行加进 used
- 板上没有 curl / transformers / flask，就认为无法做体验面或健康检查
- SSH 等 `nohup` 子进程，把主机超时当成板上失败

本 skill 给出：**账本怎么记、切分怎么判、长跑和演示怎么验收**。

## 2. 不变量 / 第一性原理

1. **Linux DRAM ≠ ION/carveout ≠ 进程 RSS ≠ VmPeak**。`MemTotal`/`MemAvailable` 是 CPU 侧；加速器包通常在独立 ION 堆；RSS 是进程常驻；VmPeak 含 mmap 虚地址。
2. **Swap=0 时用户态 OOM 墙是 `MemAvailable` 下限**，不是文件体积、也不是 ION 剩余。
3. **加速器 load 墙是「真正持包的那块 ION 堆」的 used/free**，不是文档理论值，也不是另一个同名 heap 的 total。
4. **运行时 ION > 文件字节和**。峰值用加载后、warmup 后、推理中的活测，不是 stamp 目录 `du`。
5. **未交硬件 jsonl 不得宣称 OOM 安全、已吃满内存、或该改切分**。
6. **先契约后推理**：兄弟段齐套加载并绑核，再 `run`；会话结束 Release；禁止推理后晚载 peer。
7. **体验面与压测互斥持包**：同一加速器上不要 soak 与 demo Web 双握。

## 3. 架构 / 选型决策树

```text
现在要证明什么？
  ├─ 单次质量/速度 → edge-accel-eval（不必先切内存）
  ├─ 连续 N 分钟不崩、不漂、不 IOVA → 本 skill 压测 + hwmon
  ├─ 该不该改 DRAM/ION 切分 → 先看压测序列，再走 §3.1
  └─ 人要在浏览器里用完整多模态 → 压测过后再起单进程 Web
```

### 3.1 要不要改切分

在**已齐套、正在推理**时采样，不要用空闲板。

```text
记四笔账（同一时刻）：
  A  DRAM Available（Swap=0 时的用户态墙）
  B  推理 PID 的 RSS / RssAnon（词表、numpy、桌面不在这里就别算进模型）
  C  持包 ION 堆：infer PID 的 live client + footer total
  D  常驻占用（显示/ISP/桌面 AnonPages）

  ├─ A 的 min 仍明显高于产品地板（建议 ≥256 MiB，或 ≥10% MemTotal）
  │     且 C.used × 1.15 + ISP/显示 < C.total
  │     → 保持切分；不要为「感觉 2G 小」去砍 ION
  ├─ A.min 触地板或出现 oom-killer，且 C 仍有 ≥30% free
  │     → 才允许从 ION 匀少量给 DRAM；匀完后 C 仍须 ≥ peak_used×1.2 + 显示/ISP
  ├─ load/IOVA 失败而 A 健康
  │     → 加大持包 ION（或杀争用进程），不要加 DRAM
  └─ 禁止：ION 砍到「文件和」；DRAM+ION 相加当总内存；用 VmPeak 当 RSS
```

桌面会话（gnome/Xorg）常比推理进程更吃 DRAM。先停非必要 GUI/压缩进程，再考虑改切分。

**切分落地**：只走厂商已验证脚本或已签名镜像。禁止手改 AVB boot 槽内 DTB/carveout 寄存器——地址越物理 DRAM 会内核 panic，文件变更会 `Hash mismatch` 后复位。救砖见 `embedded-ab-avb-boot`。

## 4. 标准操作流程 SOP

1. **run_meta**：主机角色、stamp、三包路径与体积、绑核、是否独占、Swap、`MemTotal`、ION 堆名与 total。
2. **杀争用**：只按 `comm==` 点名杀压缩/占核 daemon；禁止 `pkill -f`。
3. **齐套 load**：视觉/预填充/解码（或产品等价兄弟段）在任何 `run` 之前加载并绑核；`HB_NN_ENABLE_MEM_LRU_CACHE=0` 除非对照实验明确打开。
4. **任务冒烟**：同 feed 文本 + 看图 greedy；句子门与 TTFT 分列。板上无分词器则 **host detok**，不要把 token id 当失败。
5. **启动 hwmon 再静音**：1 Hz 写**文件** jsonl。`dup2(/dev/null)` 丢掉 skip-Softmax 刷屏时，采样器不得走 stdout。
6. **采样字段（最低集）**：
   - `/proc/meminfo`：MemTotal/Free/Available、AnonPages、Cached、Swap*
   - `/proc/<pid>/status`：VmRSS、RssAnon、RssFile、VmPeak、VmSize
   - ION debugfs：每个候选 heap 的 **live 表 + footer `total`**，在「allocations (info is from last known client)」**处截断**
   - BPU：实际可读的 `ratio` 节点（不要死写不存在的 `class/bpu/.../ratio`）
   - `/proc/stat` 差分得到 cpu_pct；进程 utime 得 proc_cpu_pct；loadavg
7. **长跑**：产品窗口（常见 ≥10 min）轮转 held-out；每轮任务结果 + 当时 hwmon 快照。SSH 用 `setsid`/`nohup` 后**短超时**，轮询 `n_turns`/`fatal`，不要等子进程 stdout。
8. **Release 后再采两次**：进程内 `del`+`gc` 一次；**进程退出后**再采一次系统账。Release 成功 ≠ RSS 立刻归零。
9. **切分结论**只写：A/B/C/D 的 min/p50/max、持包 heap 名、建议保持或匀多少、否证项。
10. **演示 Web（可选，压测之后）**：单进程、预载、单飞锁、stdlib `http.server`；上传图+prompt；页上活显 Available/RSS/持包 ION/BPU。健康检查用板上 Python `urllib`，**不要假设有 curl/flask**。RoPE/分词在板侧自洽（表或 BPE），禁止把 feed 里某次 dump 的 `dec_cos_{t}.npy` 当任意长度公理。退出 SIGTERM 必须 Release。
11. 调查 md 进 `docs/investigations/`；原始 jsonl 进 `<data_root>/eval/<TASK>/`。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| HBM 文件 1.6G「肯定 OOM」 | soak 中 Available min、RSS max、持包 ION used |
| VmPeak 3.5G | 与 RSS/Available 分列；虚地址不是 DRAM |
| 某 sysfs ratio=null | 换到真实节点后再报利用率 |
| load 成功 | 长跑 ok_rate、无 IOVA、句不漂 |
| curl 通 | 板上 `urllib`/`GET /health`；无 curl 不是服务失败 |
| 页面能打开 | 真实图+文本 greedy 过任务门，且统计面板是活采样 |

**通过标准**：长跑前任务冒烟过；jsonl 覆盖全程；ION used 来自 footer/live 而非历史行；切分建议能用不等式写出来。

## 6. 故障分类学

| 症状 | 可能原因 | 否证 |
|------|----------|------|
| Available 很低、RSS 不大 | 桌面/其它进程 AnonPages | 对照 PID 列表与 AnonPages |
| ION used 远大于文件和且恒定 | 把 last-known 行加进去 | 看 footer `total` 与 live client |
| ION used 几乎不变但任务在跑 | 采错 heap（ISP CMA vs 持包 carveout） | 用 infer PID 对 live client |
| BPU ratio 全 null | sysfs 路径错，或采样被静音 fd 误伤 | 板上 `find`/`cat` 该节点 |
| SSH 180s 超时、板上仍在跑 | 等了 nohup 管道 | 轮询 summary；launch 短超时 |
| Web 健康检查失败 | 无 curl | Python urllib 打 localhost |
| 板端乱码句 | 无 transformers | host detok 或板侧 BPE 对齐 HF |
| Release 后 RSS 不降 | 进程还在、mmap 未卸 | 等进程退出后再采 |

## 7. 反模式与理由

| 错误本能 | 为何失败 | 正确做法 |
|----------|----------|----------|
| DRAM+ION 加总 | 不是同一物理池 | 分列两堵墙 |
| 按 stamp `du` 切 ION | 运行时缓冲更大 | 用推理中 peak_used×裕量 |
| 为空闲板「省 ION」 | 推理峰值才是约束 | 齐套推理时采样 |
| 压测不带 hwmon | 无法为切分举证 | 1 Hz 文件 jsonl |
| 为体验面再 load 一套 | IOVA / 双握 | 停 soak 再起 Web，或相反 |
| 把 feed dump 的 RoPE 当产品 | 任意 prompt 会越界或全零 | 导出 0..cache-1 表 |
| 官方 monitor 当 OOM 公理 | 口径不同 | 本 skill 的 A/B/C 仍要采 |
| 手补丁 boot DTB 匀 ION | AVB 废槽 + 越界 panic | 厂商脚本/已签名镜像 |

## 8. 交付 / 复盘清单

- [ ] run_meta 含 Swap、MemTotal、ION 堆名
- [ ] 冒烟句 + 长跑 ok_rate / 是否锁死
- [ ] hwmon min/p50/max：Available、RSS、持包 ION、BPU ratio
- [ ] 切分建议：保持 / 匀 DRAM / 匀 ION，带不等式
- [ ] 若有 Web：预载、单飞、Release、活统计、无 IP 进文档
- [ ] 调查 md + `<data_root>/eval/<TASK>/`

## 9. 相关

- `edge-accel-eval` / `edge-accel-improve`：质量与速度深评、按层改
- `edge-bpu-runtime-iova`：齐套、粘滞序、Release
- `horizon-bpu-ptq`：编译门禁
- `field-validation-method`：O-H-V-C
- `rdk-official-catalog`：官方采集器只作线索
- `embedded-ab-avb-boot`：AVB/A-B 槽；禁止用废签名的方式改 ION DTB
- `remote-ssh-dev` / `privacy-github` / `utf8-chinese-docs`
