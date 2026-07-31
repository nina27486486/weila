# 薇拉项目交接文件

更新日期：2026-07-31
项目位置：仓库根目录

## 0. 2026-07-24 1.0 发布准备

- 新增版本化 `AcceptanceReportV1`，播放器诊断和 FakePlayer 调试页均可复制脱敏 JSON。
- 报告只保留不透明内容/线路标识、媒体主机名与数值指标，禁止完整 URL、请求头、凭据、
  文件路径和弹幕正文。
- 弹弹play AppId/AppSecret 改存 Windows Credential Manager 的
  `Weila/Dandanplay`，启动时回读校验成功后才清理旧 Hive 明文。
- 设置页保存、清除、迁移重试及播放器初始化统一经过 `DanmakuCredentialManager`；
  生产环境不再回退读取 Hive 明文。
- 真实弹弹play API 测试只读 Windows 安全凭据或显式环境变量，不再复制
  `settings_box.hive`。
- CI 改为 `flutter test --coverage`，`tool/check_coverage.dart` 强制全仓 ≥70%、
  验收报告/凭据模块 ≥85%。7 月 30 日审查前基线分别为 72.93% 和 87.06%。
- 新增 `PRIVACY.md`、`docs/MAINLAND_ACCEPTANCE_MATRIX.md` 与
  `docs/RELEASE_CHECKLIST_1.0.md`。
- `player_page.dart` 与 `detail_page.dart` 的主体均降到约 900 行；媒体生命周期、
  弹幕会话和详情加载/片源确认已提取为可测试控制器。7 月 30 日审查前基线为
  369 项通过、1 项真实 API 测试按设计跳过。
- Windows 包装流水线生成便携 ZIP、每用户 Inno Setup 安装器与 `SHA256SUMS.txt`，
  并提供 ZIP 内容、静默安装、启动、卸载和用户数据/凭据保留的烟雾脚本；当前机器
  已完成覆盖安装与可视启动，干净账户的静默安装/卸载仍待最终验收。
- 播放器底部控制栏常驻“验收报告”入口，正常播放也可随时复制安全 JSON；报告优先使用
  当前线路的实时诊断快照，避免换线后误用上一线路数据。
- 7 月 31 日主人完成大陆标准矩阵并回传 12 份独立有效的安全报告：樱花 6/6、
  非凡 6/6，播放失败 0；全体首帧中位数 5.032 秒、单次最大 6.581 秒，最长单次
  重缓冲 14.785 秒。
- 12 个会话的弹幕获取、解析、排队和渲染均大于 0，`errorStage = "none"`；
  主人同时确认 seek 后无弹幕洪峰。
- 报告暴露并修复了“直接打开非首集仍加载首集弹幕”，以及 `media_kit` 一次性首帧
  Future 被换集/换线重复使用导致的 0 秒失败误报；新候选包仍需复验非凡失败样本。
- 主人复验发现拖动进度条会补发整个跨越区间的弹幕；控制器现已在显式 seek、回退和
  明显前跳时二分重定位队列并清除旧画面。`幼女战记2` 与
  `banGDream! YUME-MITA` 的标题差异也已加入季度和装饰符号归一；主人已在大陆候选包
  中分别确认两部作品能加载并渲染真实弹幕。
- 7 月 30 日开始对当前 67 项状态改动做 1.0 收口审查。已确认所有改动位于
  `codex/weila-1.0-readiness` 隔离工作树；最终风险、测试、构建和建议提交分组见
  `docs/RELEASE_READINESS_REPORT_1.0.md`。
- 7 月 31 日重新验证静态检查、377 项默认测试、72.98% 全仓覆盖率、87.75% 关键模块
  覆盖率均通过；Windows ZIP/安装器构建此前已通过。Credential Manager 启动异常、
  安全报告严格允许列表、弹幕异步晚到洪峰 3 项发布阻断均已用失败回归测试复现并关闭。
- 播放器、`media_kit`、集数/片源解析和详情页错误现统一输出受控操作名与
  `failureKind`，不再记录完整媒体 URL 或展示底层异常；Windows EXE 元数据已统一为
  `Weila`，并补充源码泄漏、资源元数据和版本一致性回归测试。
- 主人已确认当前账户覆盖安装通过，收藏、历史、追番数据和弹幕服务凭据均保留。
  当前仍不得改为 `1.0.0+5`、打 `v1.0.0` 或发布；还需完成 Git 历史整理、目标提交
  CI，以及干净 Windows 环境的安装/卸载、下载保留和 SmartScreen 验收。

## 0.1 2026-07-16 双目录分类浏览升级

本轮已在脏工作区内完成分类基础设施与页面联动，尚未提交：

- 分类页改为“发现动画 / 可播放片库”双标签，默认发现动画。
- 新增 `lib/models/catalog/` 与 `lib/services/catalog/`：稳定不透明 `contentId`、规范题材/年份/季度/形态/状态/地区/评分、外部引用、结构化播放引用、游标、缓存与身份合并。
- 发现动画以 AniList 为主、Jikan 限流回退；CMS 分类能力统一通过插件 `catalog` 可选配置接入，单次最多扫描 3 个上游分页、详情并发最多 3，不探测真实媒体 URL。
- 版本化 Hive 盒：`catalog_entries_v1`、`catalog_refs_v1`、`catalog_query_cache_v1`。元数据列表默认 24 小时、CMS 列表 30 分钟、播放绑定 6 小时；网络失败时可回退过期缓存。
- 分类筛选包含题材 AND、多年份、季度、形态、状态、地区、评分与排序；可播放片库额外含片源与更新时间。
- 设置页新增“显示 18+ 目录内容”，默认关闭并持久化。
- `/detail` 与 `/player` 支持可选 `contentId`；元数据作品可先收藏/追番并查找播放源，手动确认 CMS 后写入结构化绑定。
- 收藏、追番、历史、下载只追加可空 `contentId` / `episodeId` 并双写，旧 URL 字段和 Hive key 未重键、未删除、未自动合并。
- 目录定向测试 98 项通过，最终全仓 `flutter analyze` 无问题；完整 `flutter test` 为 321 项通过、1 项按设计跳过。
- Windows Release 脚本验证通过，产物为 `build/windows/x64/runner/Release/weila.exe`，压缩包为 `build/windows/x64/runner/weila-0.4.0-windows-x64.zip`。

目录相关重点文件：

- `lib/pages/discover/category_browse_page.dart`
- `lib/pages/discover/catalog_controller.dart`
- `lib/pages/discover/anime_catalog_view.dart`
- `lib/services/catalog/hive_catalog_repository.dart`
- `lib/services/catalog/providers/`
- `lib/services/catalog/catalog_hive_stores.dart`
- `lib/services/catalog/catalog_detail_binding.dart`

自动验收仍不包含真实视频与媒体线路可达性；按主人要求继续留给中国大陆网络最终验收。

## 1. 项目一句话

薇拉是一个 Flutter Windows 桌面端动画追番与播放应用，核心体验包括首页推荐、发现/分类、详情、资料库、追番、下载缓存、播放器、弹幕和本地历史收藏。当前产品已经有比较明确的“天空日记 × 动漫杂志”视觉方向，并加入了看板娘、液态玻璃导航、动漫卡片、海报轨道等美术设计。

## 2. 当前仓库状态

当前 `master` 跟 `origin/master` 处在同一个提交上，但工作区存在大量未提交改动。这些改动大多属于最近一轮页面美术、交互、看板娘、事件驱动刷新和下载服务优化，不要随意 reset 或 checkout。

已观察到的改动类型：

- 视觉与交互：`lib/widgets/artwork/`、`lib/widgets/liquid_glass_surface.dart`、`lib/widgets/vira_mascot_badge.dart`、`lib/widgets/left_sidebar.dart`、`lib/widgets/vira_page_chrome.dart`
- 页面改造：`home`、`detail`、`library`、`player`、`download`、`history`、`track`、`collect`
- 播放器拆分：`lib/pages/player/widgets/`
- 详情页拆分：`lib/pages/detail/widgets/`
- 下载服务：`lib/services/download/download_settings.dart`、`segment_downloader.dart`、`download_service.dart`
- 收藏/历史/追番事件驱动：`lib/services/library/library_event_bus.dart`、`history_collect_repository.dart`、`lib/stores/history_collect_store.dart`
- 看板娘与图标资源：`assets/images/weila_app_icon.png`、`weila_brand_badge.png`、`weila_brand_badge.webp`、`windows/runner/resources/app_icon.ico`
- 测试新增/更新：下载、事件总线、组件拆分、液态玻璃、海报轨道、设置等相关测试

交接后第一步建议运行：

```powershell
git status --short --branch
flutter analyze
flutter test
```

如果要做 Release，再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/package_windows_release.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows_package.ps1
```

## 3. 已完成或接近完成的方向

- 核心四页视觉从普通 Material 风格升级为“天空日记 × 动漫杂志”。
- 封面卡片统一成 A 方案卡片风格，并加入更动漫化的海报与看板娘装饰。
- 首页/发现/资料库中多个番剧封面区域改成更完整的卡片样式。
- 本季选片/海报轨道增加可拖动的看板娘拉动条，并支持减少动态效果。
- 顶部导航与部分按钮引入 Apple liquid glass 方向的液态玻璃质感。
- 项目图标与品牌区域已接入看板娘相关资源。
- `poster_rail.dart` 已做过瘦身，相关组件拆到 `lib/widgets/artwork/`。
- `detail_page.dart`、`artwork_components.dart`、`player_page.dart` 已开始拆大文件，但 `player_page.dart` 和 `detail_page.dart` 仍偏大。
- 缓存/历史/追番刷新已改向事件驱动，减少页面互相手动刷新的耦合。
- 下载服务已推进分片重试、并发、失败原因、代理设置等能力。

## 4. 用户最新真实反馈

主人周围朋友体验后的主要问题：

- 视频加载有点慢。
- 有些视频画质低，用户无法自己切换画质。
- 弹幕功能不完整，现在体验上像只有测试弹幕。
- 分类浏览维度太少，用户感觉只有国家/地区分类，缺少类型、题材、年份、季度、状态等真正有用的筛选。

这些问题目前更偏“内容与播放基础设施”，不是继续加美术就能解决。

## 5. 关键技术判断

### 播放慢与画质问题

现在播放器仍偏“拿到一个 URL 就播放”。CMS 数据源可能有多组播放线路，但现有模型基本会把播放入口压成单个 `episode.url`，播放器侧缺少明确的播放源、清晰度、线路健康度和失败诊断模型。

建议下一轮优先建立：

- `PlaybackSource`：线路名、来源、host、headers/referer、健康分。
- `PlaybackVariant`：Auto、1080P、720P、480P、原始 URL、码率/分辨率。
- 播放前轻量探测：短超时并发探测 2-3 条线路，选择首帧更快、清单合法、近期健康分更高的线路。
- 手动线路切换与清晰度切换 UI。
- 如果源本身只有低清晰度，需要明确提示“当前线路仅提供该清晰度”，不要假装能升清。

### 弹幕问题

弹幕渲染层已有基础能力，但数据层和匹配流程不足。当前主要问题是：

- 未配置真实弹幕服务时会加载测试弹幕，用户容易以为弹幕是假的。
- 番名和集数匹配不够稳，可能匹配不到或匹配错。
- 弹幕服务状态没有清楚告诉用户：未配置、搜索中、无匹配、加载失败、已加载 N 条。
- 代理设置需要和全局网络/下载设置统一。

建议下一轮做：

- Release 中默认不显示测试弹幕，只在 debug/dev 下保留。
- 增加弹幕状态 UI。
- 做候选匹配列表，让用户第一次选择正确番剧/季度/集数，之后记住映射。
- 增加关键词过滤、密度限制、类型过滤。

### 分类浏览问题

当前发现页已经有分类 UI，但数据管线仍偏弱：有些筛选是对当前已加载列表做本地过滤，不是真正的全量分类检索。需要把“番剧身份/元数据”和“播放源”拆开。

建议下一轮做：

- 建立稳定内容 ID，不要用播放 URL 当作品身份。
- 元数据来源负责标题、别名、年份、季度、题材、类型、评分、状态、封面。
- CMS/插件来源只负责可播放线路映射。
- 分类维度至少包括：类型、题材、年份、季度、连载状态、地区、TV/剧场版/OVA、评分、可播放、更新时间。

## 6. 推荐下一阶段路线

推荐选择“播放优先”的渐进路线，不建议马上做一次大重构。

1. 播放源与清晰度模型
   先保留 CMS 的所有播放组和 HLS master playlist 变体，播放器能显示线路与清晰度。

2. 播放探测与健康度
   播放前短探测，记录首帧时间、manifest 时间、失败原因、重缓冲次数，慢线路自动降权。

3. 播放器 UI
   在控制栏增加线路/清晰度入口，保持纯黑舞台，不让装饰抢视频内容。

4. 弹幕真实化
   移除 Release 测试弹幕兜底，加入弹幕匹配、状态、过滤和全局代理。

5. 分类浏览升级
   建立元数据索引和多维筛选，再接入播放源映射。

6. Android 评估与迁移
   等播放、弹幕、分类的核心数据模型稳定后再推进 Android，会少走很多回头路。

粗略时间成本：

- 播放源/清晰度/探测：7-12 个工作日。
- 弹幕真实化：4-7 个工作日。
- 分类浏览升级基础版：5-8 个工作日。
- 更完整的元数据索引与去重：约 2 周。

## 7. 目前项目优点与短板

优点：

- 视觉方向已经立起来了，有独特气质，不再像普通模板应用。
- 桌面端页面结构、卡片、海报、液态玻璃、看板娘已经形成品牌记忆点。
- 下载服务、事件驱动刷新、组件拆分、测试体系都在向工程化靠近。
- Flutter Windows 侧已有较完整的播放、下载、收藏、历史和设置闭环。

短板：

- 播放链路仍是最大体验风险，尤其是源选择、首帧速度、清晰度和失败恢复。
- 弹幕还没从“能显示”升级到“可信可用”。
- 分类浏览没有形成真正的内容目录能力。
- `player_page.dart` 与 `detail_page.dart` 仍偏大，后续改播放/详情时要继续抽控制器和纯展示组件。
- README/ROADMAP/DEVLOG 当前在终端输出里有中文编码乱码迹象，修改文档时务必按 UTF-8 保存并检查显示。

## 8. 新对话建议起手式

新对话开始后，建议先读：

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `git status --short --branch`
4. `lib/pages/player/player_page.dart`
5. `lib/services/plugin/plugin_service.dart`
6. `lib/services/plugin/cms_api_service.dart`
7. `lib/services/danmaku/danmaku_service.dart`
8. `lib/pages/discover/category_browse_page.dart`

如果主人要继续开发，最推荐从“播放源/清晰度模型”开始，而不是继续加视觉效果。因为朋友反馈的四个问题里，播放源模型能直接改善“加载慢”和“画质不可切换”，也会为下载、历史、弹幕和 Android 迁移打基础。
