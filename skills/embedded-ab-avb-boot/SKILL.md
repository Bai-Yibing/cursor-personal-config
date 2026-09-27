---
name: embedded-ab-avb-boot
description: >-
  Recover and persist A/B boot on embedded boards that use U-Boot, Android
  Verified Boot, overlayroot, and vendor slot metadata. Use when a DTB/ION
  patch, Hash mismatch, SPL/OP-TEE loop, Hobot$ or U-Boot prompt, ab_select,
  slot_suffix, ota slot tool, or overlay /boot vs mmc boot partition comes up.
---

# 嵌入式 A/B + AVB 启动恢复

适用于：U-Boot 先选槽再 AVB，失败即复位；Linux 根在 overlay/verity 上。现场例证来自 S 系列 RDK，方法不绑单一产品名。

## 1. 问题定义

改设备树、ION carveout 或 `/boot` 文件后出现：MCU 热复位、SPL 循环、`Hash of data does not match`、设了 `bootslot` 仍打印另一槽。常见误判：把 Linux `/boot` 当 U-Boot 所读介质；把十进制分区号喂给 U-Boot；用 `saveenv` 或 systemd `bootctl` 当切槽。

## 2. 不变量 / 第一性原理

1. **AVB 校验整槽，不是单文件。** 改 DTB/删同目录文件都会让该槽哈希失败。文件拷回 ≠ 槽重新签名。
2. **`boot` 会先跑槽选择器。** 选择器从 misc/AON 读槽并覆盖内存里的 `bootslot`/`slot_suffix`。只 `setenv` 再 `boot` 通常无效。
3. **编译进 U-Boot 的 `bootcmd`/`ab_select_cmd` 可能压过 `saveenv`。** 冷启动必须再 `printenv`；能留下的常常是 `bootslot`、`slot_suffix`、`bootdelay`。
4. **用户态槽查询 ≠ ROM 当前槽。** OTA/`-g` 显示 B 时，U-Boot 仍可能 `Booting slot: a`。持久化要写 next-expected / misc，再看一次无按键启动。
5. **U-Boot 分区号是十六进制。** Linux `mmcblk0p14` 对应 `mmc 0:e`，不是 `0:14`。
6. **overlay upper 的备份 U-Boot 不可见。** 救援文件必须来自 boot 槽或只读系统包路径。
7. **ION 地址必须落在物理 DRAM map 内。** 手改寄存器超出窗口会在 initramfs 前 panic；维护 `rdinit=/bin/sh` 救不了。
8. **打断启动只在 Linux/U-Boot UART。** MCU 日志路按空格无效。终端独占串口时 Agent 不要抢同一 COM。
9. **Agent 不擅自 reboot、不 `mmc write`/`dd` boot、不在未证明通路前 `saveenv`。**

## 3. 架构 / 选型决策树

```text
现象？
  ├─ MCU warm reset / 无 U-Boot 字样 → 换 Linux UART；921600 先于乱试波特率
  ├─ SPL→ATF→OP-TEE 循环、无 login
  │     ├─ 能抢到 U-Boot 提示符 → 只读列出两槽 DTB/内核，走完好槽
  │     └─ 抢不到 → 从 SPL 起按住空格；仍无则停，不要刷机
  ├─ Hash mismatch / resetting → 该槽 AVB 已废；禁止对该槽 `boot`
  └─ 能进 Linux 但不自动 → 先钉完好槽，再厂商 OTA/misc；不要 systemd bootctl
要改 ION/CMA？
  → 厂商已验证脚本或已签名镜像
  → 禁止直接覆盖 AVB boot 内 DTB（见 edge-board-system-test 切分门）
```

## 4. 标准操作流程 SOP

### 4.1 交互救援（RAM 环境，先不 saveenv）

1. 从 SPL 起按住空格，停在 U-Boot 提示符。
2. `printenv bootcmd avb_boot ab_select_cmd slot_suffix`；`part list mmc 0`。
3. `ext4ls` 两槽 `/hobot`（或板级 DTB 目录），对比大小是否与系统包原厂一致。
4. 对完好槽（示例为 B）：

```text
setenv bootslot b
setenv slot_suffix _b
run avb_boot
run distro_bootcmd
```

不要输入 `boot`。预期：`Using slot b`、`Verification passed`、`ubuntu login:`。

5. 登录后确认：`tr ' ' '\n' < /proc/cmdline | grep slot`。

### 4.2 脏槽文件（可选，仍当 AVB 废槽）

从包内原厂 DTB 拷回对槽的 Linux 设备节点。先删 `.bak` 与 0 字节半成品，避免小 boot 分区 ENOSPC。拷完也不要切回该槽。

### 4.3 无人值守

1. 找到厂商槽工具（常见在 `/usr/hobot/bin/` 一类路径），只读 `-g` / get-slot。
2. 若查询与 U-Boot `Booting slot` 不一致：按厂商接口写 **next expected** 到完好槽，不要手写 `ubootenv`。
3. 用户复位；不按空格。验收：一次 SPL 到 login，且 cmdline 槽与 OTA 当前槽一致。
4. 若 `saveenv` 改 `bootcmd`/`ab_select_cmd`：冷启动再 `printenv`；还原则放弃这条路。

应急仍用 §4.1 四条。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| `saveenv` 打印 Writing OK | 断电后再 `printenv` 键值仍在 |
| Linux `/boot` 文件 cmp 一致 | U-Boot AVB `Verification passed` |
| OTA 查询已是目标槽 | 无按键启动的 `Booting slot` / cmdline 一致 |
| systemd `bootctl` 存在 | 该二进制确实实现 Android 槽 API |

## 6. 故障分类学

| 症状 | 原因 | 否证 |
|------|------|------|
| SPL 死循环无 Hobot$ | 内核 panic 或 AVB 复位太快 | 按住空格能否进提示符；有无 Hash mismatch |
| 设了 bootslot 仍 slot a | ab_select 覆盖 env | `boot` vs `run avb_boot` 对照 |
| `mmc 0:14` 只有 data/ | hex 分区号误用 | `part list`；p14 应对 `0:e` |
| AssertionError 写 DTB | 打印格式 `0x01` vs `0x1` | `cmp` 是否 MATCH |
| bootctl 无 get-current-slot | EFI 工具撞名 | `bootctl --help` 是否 systemd |
| 查询 B、启动 A | misc 当前仍 0 | U-Boot 打印；写 next-expected |

## 7. 反模式与理由

| 做法 | 为何失败 |
|------|----------|
| 手补丁 AVB boot DTB | 整槽哈希废；地址可越 DRAM |
| `rdinit=/bin/sh` 修 ION 坏树 | 崩溃早于 init |
| `setenv` 后 `boot` | 选择器把槽写回去 |
| `saveenv` 改 bootcmd 当公理 | 编译默认可回滚 |
| `dd`/`mmc write` 刷 boot | 不可逆，且无签名仍过不了 AVB |
| Agent 抢独占串口 / 擅自 reboot | 对端静默或冲掉现场 |

## 8. 交付 / 复盘清单

- [ ] 完好槽 AVB 通过且 login
- [ ] 无按键复位后 cmdline 槽位一致
- [ ] 脏槽未当可启动槽
- [ ] 未把 IP/串号写入文档
- [ ] ION 需求未用同一方式再补丁 DTB

## 9. 相关

- `edge-board-system-test`：DRAM/ION 切分门；禁止用废 AVB 的方式匀堆
- `rdk-official-catalog`：BSP 刷机须用户确认；不覆盖本 skill
- `remote-ssh-dev`：串口角色、独占、取材
- `edge-bpu-runtime-iova`：上板多模型；启动恢复之后才谈加载
- `field-validation-method` / `privacy-github`
