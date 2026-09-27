---
name: industry-watch
description: >-
  Gather work-gated external intel: a still-valid catalog from today
  backward, a previous-calendar-day brief, or a prior-art scan before
  new work. Includes same-SoC community runtimes. Use when the user asks
  for 情报简报, 写情报简报, 搜集信息, 整理存量, 搜集官方材料,
  industry-watch, 行业动态, 昨天更新了什么, 开新项目前查重,
  避免重复造轮子, prior-art. Do not write the leadership work 日报.
---

# 外部情报早报（镜头门控）

每天早上由用户**手动调用**。写的是「外面更新了什么、要不要管」，不是「我们昨天做了什么」。

观察清单、关键词和渠道真源在情报项目树，不进本 skill 正文：

`<workspace_root>/docs/industry-watch/`

（`SOP.md`、`search-net.md`、`keywords.md`、`topics.md`、`channels.md`、`watchlist.yaml`、`search-net.yaml`、`briefs/`、`catalog/`、`prior-art/`）

## 1. 问题定义

失败有四种：把「AI 新闻」当情报；没搜现有轮子就开项目；只看昨天所以基线失踪；以及**只扫已登记仓所以漏掉尚未登记的同芯社区项目**。本 skill：先对焦，再按档采集，再用显著度门。存量必须带指纹发现。

## 2. 不变量

1. **时间窗分档**：早报 = 前一自然日；存量 = 从写作日向前仍有效；查重 = 针对拟做之事的存量检索。
2. **镜头门控**：P0 每天扫；P1 必须被当天镜头点名；P2 默认关。存量可打开 org/user 列表，但仍按工作线过滤。
3. **可行动才进正文**：每条要能映射到一个工作元素，并给出 `忽略` / `跟踪` / `试用` / `对照门禁`。
4. **情报 ≠ 验收**：官方 cosine、zoo FPS、博客墙钟不是芯片能力，更不是上板结论。
5. **不改配方**：发现工具链 breaking 只记录冲突；量化 YAML、核数、混精度仍走现场 skill。
6. **空档要有结构**：无过门条目仍须 BLUF、覆盖矩阵、未过门表、情报缺口。一句话空档不合格。
7. **与工作日报隔离**：工作日报走 `daily-report`。
8. **开题必查重**：新 TASK/工作区/「从零实现」先 `templates/prior-art.md`。star 加权分不是同芯门。

## 3. 决策树

```text
用户要早报 / 搜集信息 / 官方材料 / 开题查重？
  ├─ 措辞是工作「日报 / 今日总结 / 经验」→ daily-report，本 skill 停
  ├─ 要改 PTQ / 上板 / reboot → 本 skill 停，转领域 skill
  ├─ 搜集信息 / 整理存量 / 第一次建仓
  │     → snapshot + **discover** + 按工作线写 catalog/
  │     → unknown 命中必须 hit-card，合格才进 watchlist
  ├─ 开新项目 / 避免重复造轮子 / prior-art
  │     → 读 prior-art/README.md + templates/prior-art.md
  │     → GitHub 先，再 HF/PyPI；分阶段停
  │     → 结论：采用 | 改编 | 自建；落 prior-art/
  └─ 情报简报
        → SOP + Current focus → 每日采集 → 过门后写 briefs/
```

找不到 `docs/industry-watch/`：不要临时发明第二套渠道；标明路径缺失并停。不要 `/loop` 定时，除非用户另说。

## 4. SOP

1. **对焦**
   读情报项目 `docs/PROJECT_STATE.md`、上一份 `briefs/`、活跃业务仓 `PROJECT_STATE.md` 的 Current focus。镜头含视觉语言导航时再读对应任务说明。口语别名先查 `keywords.md`，不要按「导航 / 视觉 / 大模型」泛搜。

2. **机械采集**（不克隆、不镜像厂商 90+ skill）

```bash
cd <workspace_root>/docs/industry-watch
python scripts/collect_watchlist.py --date yesterday --topics <lens>
# 存量：
python scripts/collect_watchlist.py --mode snapshot --topics <lens>
python scripts/collect_watchlist.py --mode discover
```

`GITHUB_TOKEN` / `HF_ENDPOINT` 只放环境变量。Hugging Face 直连失败可回退镜像；API 失败 ≠ 模型已删除，改 WebFetch 模型卡。

3. **定向复核**
   只打开：脚本命中的 release/commit、P0 官方文档/组织页、镜头对应模型卡。
   允许：`<官方仓> release OR changelog after:YYYY-MM-DD`。
   禁止：`AI news today`、`best edge LLM`、`robotics weekly`、论文日报、仿真器每日 tag。
   打不开的页面写「未取到」，不编造。

4. **显著度门**（过一扇才能进正文）
   官方版本；我方在用的权重/代码 tag；工具链字段/算子/运行时行为；**同芯同任务**的独立运行时/配方仓（不看 star、不限官方 org）；与现场门禁冲突的话术。
   文档错字、demo 换皮、云端 70B、跨芯片 TRT/RKNN、重复已知冲突 → 丢弃。过门后仍要能回答「所以呢」。对照 `community-edge-npu`。

5. **写简报**
   拷贝 `templates/daily-brief.md`。主体是**需求 → 开源对照表**（采用结构/改编/对照/避开），不是昨天 Git 列表。窗口增量单独一节。空档也要有对照表。

5b. **开题查重**（非每日）
   `templates/prior-art.md` → `prior-art/`。禁止用 wheel-hub 的 star 分否决同芯低星仓。

5c. **存量目录**（不限昨天）
   `templates/catalog.md` + `templates/item-card.md` → `catalog/`。主线用表；必须做相邻圈（L2/L3，最多 12 张卡片）。发散 = 同芯旁路或同任务下一跳，不是论文日报。L4 进避开表。禁止为「显得全面」扫 X5 BSP 和人形操作器。
   **必须**跑 `--mode discover`（`search-net.yaml`）。unknown 用 `templates/hit-card.md` 标注后才能进 watchlist。网说明：情报树 `search-net.md`。
   用户要「全面 / 多工作线 / 小参数模型 / 多社区」时写 `templates/landscape.md` → `catalog/YYYY-MM-DD-全景.md`：每个项目介绍+分析，每线综合，文末全文综合。禁止只填表。

6. **收尾**
   `utf8-chinese-docs` 校验；更新情报项目 `PROJECT_STATE.md` 的上次日期与待跟。连续 5 个工作日某 P1 零命中，建议降级，不要空转。

## 5. 度量与门禁

| 虚荣 | 验收 |
|------|------|
| 贴了很多链接 | 按需求分组；每行有入口、新鲜度、能推进哪一步、裁决 |
| 只写昨天一条 skill 发版 | 对照表仍在；增量另开一节 |
| 一句话空档 | BLUF + 覆盖矩阵 + 未过门表 + 缺口 |
| 写满八条 | 过门少而可行动 |
| 开题直接写代码 | `prior-art/` 有采用/改编/自建结论 |
| 只写昨天所以基线失踪 | `catalog/` 有主线表 |
| 只抄当前 TASK 所以漏旁路 | 存量有 L2/L3 卡片或写明零命中 |
| 只扫已登记仓所以漏 BLLM 类 | 存量有 discover JSON + 发现卡；unknown 已裁决 |

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
| 空档注水或空档无结构 | 无法决策 | 无过门也要覆盖矩阵 |
| 把情报当已上板 | 无板上证据 | 动作止于跟踪/试用 |
| star 分否决同芯仓 | 再漏 BLLM 类 | 同芯门优先 |
| 只刷新 watchlist | 未知作者永不进入 | 存量跑 discover 指纹 |

## 8. 交付清单

- [ ] 早报窗口是昨天；存量不限昨天；查重针对拟做之事
- [ ] 镜头词来自 Current focus + `keywords.md`
- [ ] 简报含 BLUF 与覆盖矩阵；空档不是一句话
- [ ] 存量含主线表 + 相邻圈（或写零命中）；条目能回答一句话价值
- [ ] 存量含 discover 结果；unknown 已填 hit-card 或写明限额未取到
- [ ] 无 IP/凭据；UTF-8 校验通过
- [ ] 未改量化配方、未上板、未 reboot、未开定时 loop

## 9. 相关

- 工作日报：`daily-report` / `work-reporting-pipeline`（不要混用）
- 厂商命令对照：`rdk-official-catalog`
- 同芯社区运行时：`community-edge-npu`
- 量化/运行时/评测门禁：`horizon-bpu-ptq` / `edge-bpu-runtime-iova` / `edge-accel-eval`
- 中文与隐私：`utf8-chinese-docs` / `privacy-github`
- 项目状态：`project-continuity` / `knowledge-lifecycle`
