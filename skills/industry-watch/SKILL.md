---
name: industry-watch
description: >-
  Produce a previous-calendar-day vendor and high-recognition open-source
  intel brief gated by the current work lens. Use when the user asks for
  情报简报, 写情报简报, 搜集官方材料, industry-watch, 行业动态, 昨天更新了什么,
  or a morning official/GitHub scan. Do not write the leadership work 日报.
---

# 外部情报早报（镜头门控）

每天早上由用户**手动调用**。写的是「外面更新了什么、要不要管」，不是「我们昨天做了什么」。

观察清单、关键词和渠道真源在情报项目树，不进本 skill 正文：

`<workspace_root>/docs/industry-watch/`

（`SOP.md`、`keywords.md`、`topics.md`、`channels.md`、`watchlist.yaml`、`briefs/`）

## 1. 问题定义

失败模式是把「AI 新闻」或整 org 动态写成早报：信噪比低，且会把厂商示例配方误当成现场门禁。本 skill 解决的是：**先对焦当前工作，再扫已锚定渠道，用显著度门过滤，落成可行动的短简报**。

## 2. 不变量

1. **时间窗**：前一自然日 `00:00–24:00`，时区 `Asia/Shanghai`。漏报可次日补一条并标明「补报」。
2. **镜头门控**：P0 每天扫；P1 必须被当天镜头点名；P2 默认关。
3. **可行动才进正文**：每条要能映射到一个工作元素，并给出 `忽略` / `跟踪` / `试用` / `对照门禁`。
4. **情报 ≠ 验收**：官方 cosine、zoo FPS、博客墙钟不是芯片能力，更不是上板结论。
5. **不改配方**：发现工具链 breaking 只记录冲突；量化 YAML、核数、混精度仍走现场 skill。
6. **空档是成功**：无过门条目就写空档，不准注水。
7. **与工作日报隔离**：工作日报走 `daily-report`（领导可读的进展与判断），不要把简报条目粘进日报当成果。

## 3. 决策树

```text
用户要早报 / 官方材料 / 行业动态？
  ├─ 措辞是工作「日报 / 今日总结 / 经验」→ daily-report，本 skill 停
  ├─ 要改 PTQ / 上板 / reboot → 本 skill 停，转领域 skill
  └─ 情报简报
        → 读情报项目 SOP + 业务仓 Current focus
        → 抽出 3–7 个镜头词（对照 keywords.md）
        → 跑 watchlist 采集（不克隆仓）
        → 只 WebFetch 命中项与 P0 站点
        → 过显著度门后写 briefs/YYYY-MM-DD-情报简报.md
```

找不到 `docs/industry-watch/`：不要临时发明第二套渠道；标明路径缺失并停。不要 `/loop` 定时，除非用户另说。

## 4. SOP

1. **对焦**  
   读情报项目 `docs/PROJECT_STATE.md`、上一份 `briefs/`、活跃业务仓 `PROJECT_STATE.md` 的 Current focus。镜头含视觉语言导航时再读对应任务说明。口语别名先查 `keywords.md`，不要按「导航 / 视觉 / 大模型」泛搜。

2. **机械采集**（不克隆、不镜像厂商 90+ skill）

```bash
cd <workspace_root>/docs/industry-watch
python scripts/collect_watchlist.py --date yesterday --topics <lens>
```

`GITHUB_TOKEN` / `HF_ENDPOINT` 只放环境变量。Hugging Face 直连失败可回退镜像；API 失败 ≠ 模型已删除，改 WebFetch 模型卡。

3. **定向复核**  
   只打开：脚本命中的 release/commit、P0 官方文档/组织页、镜头对应模型卡。  
   允许：`<官方仓> release OR changelog after:YYYY-MM-DD`。  
   禁止：`AI news today`、`best edge LLM`、`robotics weekly`、论文日报、仿真器每日 tag。  
   打不开的页面写「未取到」，不编造。

4. **显著度门**（过一扇才能进正文）  
   官方版本；我方在用的权重/代码 tag；工具链字段/算子/运行时行为；高认可开源（官方 org 或观察仓新 tag）；与现场门禁冲突的话术。  
   文档错字、demo 换皮、云端 70B、重复已知冲突 → 丢弃。过门后仍要能回答「所以呢」。

5. **写简报**  
   拷贝 `templates/daily-brief.md` → `briefs/YYYY-MM-DD-情报简报.md`。最多 8 条。取材台账只进 `_inbox/`。`试用` ≠ 开编。

6. **收尾**  
   `utf8-chinese-docs` 校验；更新情报项目 `PROJECT_STATE.md` 的上次日期与待跟。连续 5 个工作日某 P1 零命中，建议降级，不要空转。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| 贴了很多链接 | 每条有来源、日期、与镜头的关系、四选一动作 |
| 扫过整个 GitHub 组织 | 只打 watchlist；P2 未点名则零请求 |
| 官方 FPS / cosine | 现场任务指标与独占分段墙钟（`edge-accel-eval`） |
| 写满八条 | 空档也算完成 |

## 6. 故障分类

| 症状 | 原因 | 否证 |
|------|------|------|
| 和领导日报长得像 | 走错流水线 | 正文是否在问「外面更新了什么」 |
| 全是大模型八卦 | 未对焦 / 泛搜 | 每条能否映射 `topics.md` |
| HF/GitHub 全 ERR 当成删除 | 网络或限额 | 记未取到；查 `GITHUB_TOKEN` / `HF_ENDPOINT` |
| 读到官方混精度就想改 YAML | 把示例当配方 | 只写「对照门禁」，转 `horizon-bpu-ptq` |
| 把 VLN 和仿真器发版混为一谈 | 渠道未分级 | 导航基础模型看官方仓 tag；Habitat/Isaac 每日 tag 默认关 |

## 7. 反模式

| 做法 | 为何失败 | 正确做法 |
|------|----------|----------|
| 当工作日报写 | 读者和证据标准不同 | 两套模板，互不粘贴 |
| 每天扫旁路仓 | 与当前镜头脱节 | P2 关闭，点名才开 |
| 克隆官方仓做情报 | 慢、脏、易泄路径 | API + WebFetch |
| 空档注水 | 稀释「要不要管」 | 写明无过门条目 |
| 把情报当已上板 | 无板上证据 | 动作止于跟踪/试用建议 |

## 8. 交付清单

- [ ] 窗口是昨天，不是「最近觉得重要」
- [ ] 镜头词来自 Current focus + `keywords.md`
- [ ] 简报在 `briefs/`；inbox 不进正文
- [ ] 无 IP/凭据；UTF-8 校验通过
- [ ] 未改量化配方、未上板、未 reboot、未开定时 loop

## 9. 相关

- 工作日报：`daily-report` / `work-reporting-pipeline`（不要混用）
- 厂商命令对照：`rdk-official-catalog`
- 量化/运行时/评测门禁：`horizon-bpu-ptq` / `edge-bpu-runtime-iova` / `edge-accel-eval`
- 中文与隐私：`utf8-chinese-docs` / `privacy-github`
- 项目状态：`project-continuity` / `knowledge-lifecycle`
