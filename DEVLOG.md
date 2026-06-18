# 看番项目（薇拉/weila）开发日志

## 项目概览

- **名称**：薇拉（weila）
- **定位**：基于Kazumi架构的Windows桌面动漫播放器
- **技术栈**：Flutter Desktop + MobX + flutter_modular + media_kit + Hive CE + Dio
- **源码**：`C:\Users\nina\Desktop\自己vibe coding玩玩\薇拉\`
- **编译产物**：`看番Debug/weila.exe`（1.2MB）

---

## 已完成功能

### 核心架构（阶段1-4）
- [x] 项目脚手架：Flutter Desktop + modular路由 + MobX状态管理
- [x] 插件系统：支持HTML/CSS、JSON API、GraphQL（Anilist）、CMS采集站四种模式
- [x] 视频播放器：media_kit + 自定义控件（进度条、音量、倍速、集数侧边栏、键盘快捷键）
- [x] 本地存储：Hive CE（历史记录、收藏夹、追番列表、设置）
- [x] 搜索功能：跨源并行搜索，CMS结果过滤非动漫内容

### 数据源
- [x] Anilist GraphQL API（元数据、评分、标签）
- [x] Bangumi REST API（中文元数据，可能被墙）
- [x] 非凡资源 CMS API（cj.ffzyapi.com，视频源）
- [x] 樱花动漫 CMS API（yinhuadm.xyz，视频源）
- [x] Anilist→CMS桥接（元数据+视频源自动匹配）

### UI页面（阶段5-7 + 发现区）
- [x] 首页：CMS数据驱动的最新番剧/热门推荐 + 轮播横幅
- [x] 搜索页：跨源搜索 + 结果卡片
- [x] 详情页：封面+评分+标签+简介+集数网格
- [x] 播放器页：全功能播放器 + 集数切换 + 历史记录
- [x] 追番列表、观看历史、收藏夹
- [x] 设置页：插件管理（增删改查、测试）
- [x] **番剧页**：分类Tab切换 + 无限滚动分页
- [x] **剧场版页**：复用番剧页架构
- [x] **追番日历**：按星期几分组展示更新
- [x] **排行榜**：前3名领奖台 + 评分排序列表
- [x] **分类浏览**：数据源切换 + 分类Tab + 类型标签筛选

### 本次优化（2026-06-17）
- [x] 修复4个HIGH级bug（内存泄漏、空列表崩溃、Anilist单结果、类型转换）
- [x] 修复6个MEDIUM级bug（HTTP回退、播放错误处理、超时、响应式状态等）
- [x] 封面URL修复：相对路径自动拼接baseUrl
- [x] 封面防盗链：CoverImage组件自动Referer + 重试机制
- [x] 搜索过滤：按type_id屏蔽非动漫内容
- [x] 发现区5个功能全部实现

---

## 遇到的困难与教训

### 1. sed处理含行号的文件（已记录在memory）
**问题**：用sed批量替换print时，把read_file输出的行号（`     1|import ...`）当成了文件内容，导致多个文件被损坏。
**教训**：永远不用sed处理含行号的文件。用patch工具或Python处理。

### 2. CMS返回Content-Type: text/html但body是JSON
**问题**：Dio设置ResponseType.json后，对text/html的响应不自动解析，返回原始String，导致所有CMS数据解析失败。
**解决**：在HttpClient.getJson()和postJson()中加jsonDecode回退。

### 3. CMS封面URL是相对路径
**问题**：CMS API返回的`vod_pic`字段是相对路径（`upload/vod/xxx.webp`），不是完整URL。Image.network加载相对路径会失败。
**解决**：在PluginService数据源处，用`_fixCoverUrl()`自动拼接baseUrl。

### 4. CDN防盗链
**问题**：部分图片CDN拒绝无Referer的请求，返回403。
**解决**：CoverImage组件自动从图片URL提取origin作为Referer，失败后去掉Referer重试。

### 5. MobX .g.dart在中文路径下无法自动生成
**问题**：build_runner在含中文字符的项目路径下失败。
**解决**：手写所有.g.dart文件。每个@observable需要手动添加Atom，每个@action需要手动添加ActionController。

### 6. 括号匹配问题反复出现
**问题**：多次patch修改widget树后，括号不匹配导致编译错误。手动数括号极易出错。
**教训**：复杂widget树修改时，应该重写整个方法/文件，而不是逐行patch。用awk统计括号数可以快速定位问题。

### 7. Anilist搜索只返回1条结果
**问题**：GraphQL查询用`Media()`单条查询，应该用`Page()`分页查询。
**解决**：改为`Page(perPage: 10) { media(...) }`查询。

### 8. 导航方式不一致
**问题**：部分页面用`Navigator.pushNamed()`，部分用`Modular.to.pushNamed()`，导致`pop()`行为不一致。
**教训**：统一使用Modular导航，用`navigate('/')`代替`pop()`。

---

## 当前不足与待改进

### 功能缺失
- [ ] 离线缓存（侧边栏有入口但未实现）
- [ ] 稍后再看（侧边栏有入口但未实现）
- [ ] 个人中心（侧边栏有入口但未实现）
- [ ] 追番日历的按日分组是基于vod_time的，不是精确的放送日历
- [ ] 排行榜是客户端排序（拉3页后按score排），不是服务端排序
- [ ] 首页右栏日历功能是空壳（calendarData: const {}）
- [ ] 播放器全屏是假全屏（只隐藏侧边栏，没有真正的窗口全屏）
- [ ] 没有播放器画中画模式
- [ ] 没有弹幕功能

### 性能问题
- [ ] 首页轮播和卡片列表没有懒加载/虚拟化
- [ ] 搜索没有防抖（debounce），每次回车都触发全量搜索
- [ ] HistoryCollectStore每次增删都全量reload整个box
- [ ] 没有图片缓存（每次启动都重新下载封面）

### 代码质量
- [ ] Store直接实例化，没有用flutter_modular的DI
- [ ] 错误处理不统一（有的用SnackBar，有的用setState设error）
- [ ] 日志器太简陋（只有debug/error两级，无时间戳，无文件输出）
- [ ] 没有单元测试
- [ ] 部分页面逻辑臃肿（detail_page 633行、plugin_service 861行）

### 用户体验
- [ ] 没有搜索历史/自动补全
- [ ] 没有深色/浅色主题切换
- [ ] 没有启动画面（splash screen）
- [ ] 没有更新检查机制
- [ ] 分类浏览的类型标签是硬编码的，不能从API动态获取

---

## 文件结构

```
lib/
├── main.dart                    # 入口
├── app_module.dart              # 路由定义（12个页面）
├── app_widget.dart              # MaterialApp + 主题
├── models/                      # 数据模型（6个）
│   ├── anime.dart / .g.dart
│   ├── plugin.dart / .g.dart
│   ├── history_item.dart / .g.dart
│   ├── collect_item.dart / .g.dart
│   └── track_item.dart / .g.dart
├── stores/                      # MobX状态管理（3个）
│   ├── anime_store.dart / .g.dart
│   ├── home_store.dart / .g.dart
│   └── history_collect_store.dart / .g.dart
├── services/                    # 服务层
│   ├── http/http_client.dart
│   ├── plugin/plugin_service.dart  # 核心：插件系统（861行）
│   ├── parser/xpath_parser.dart
│   └── storage/storage_service.dart
├── pages/                       # 页面（12个）
│   ├── home/home_page.dart
│   ├── search/search_page.dart
│   ├── detail/detail_page.dart
│   ├── player/player_page.dart
│   ├── discover/                # 发现区（本次新增）
│   │   ├── anime_list_page.dart
│   │   ├── calendar_page.dart
│   │   ├── ranking_page.dart
│   │   └── category_browse_page.dart
│   ├── history/history_page.dart
│   ├── collect/collect_page.dart
│   ├── track/track_page.dart
│   └── settings/（4个文件）
├── widgets/                     # 通用组件（7个）
│   ├── anime_card.dart
│   ├── cover_image.dart         # 本次新增：统一封面组件
│   ├── carousel_banner.dart
│   ├── left_sidebar.dart
│   ├── right_sidebar.dart
│   ├── top_search_bar.dart
│   └── section_title.dart
├── theme/app_theme.dart
└── utils/
    ├── constants.dart
    ├── animations.dart
    ├── helpers.dart
    └── logger.dart
```

**总计**：50+个Dart文件，约12,000行代码

---

## 技术债务优先级

| 优先级 | 项目 | 原因 |
|--------|------|------|
| P0 | 图片缓存 | 每次启动重新下载所有封面，浪费流量和时间 |
| P0 | 播放器全屏 | 用户体验核心功能 |
| P1 | Store DI | 测试和维护的基础 |
| P1 | 错误处理统一 | 用户体验一致性 |
| P2 | 搜索防抖 | 减少无效请求 |
| P2 | 离线缓存 | 侧边栏已有入口，用户预期 |
| P3 | 单元测试 | 长期维护保障 |
| P3 | 代码拆分 | plugin_service太大，需要拆分 |

---

*薇拉整理于 2026年6月17日*
