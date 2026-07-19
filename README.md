# 薇拉 Weila

[![Windows CI](https://github.com/nina27486486/weila/actions/workflows/ci.yml/badge.svg)](https://github.com/nina27486486/weila/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-Windows-54C5F8.svg)](https://flutter.dev/)

薇拉是一款面向 Windows 10/11 的 Flutter 桌面动漫播放器，提供番剧发现、聚合搜索、
详情浏览、追番管理、多线路播放、弹幕与离线缓存。项目当前处于 **v0.4 开源准备版**，
仍在持续完善稳定性与数据源兼容性。

## 功能

- 首页推荐、本季新番、排行榜、分类浏览和追番日历
- Jikan 元数据与 Bangumi 中文信息桥接
- CMS 插件聚合搜索、详情解析和多播放线路
- media_kit 播放器、倍速、音量、真全屏、快捷键和下一集提示
- 弹幕显示、密度/透明度/速度/字号设置
- 播放故障诊断、自动重试、线路切换和无画面检测
- 观看历史、收藏和追番列表
- M3U8 离线缓存、暂停、恢复和删除
- 深色/浅色主题、封面缓存、搜索历史和加载骨架屏

## 快速开始

### 环境

- Windows 10 或 Windows 11
- Flutter stable，推荐 `3.41.9` 或更新版本
- Visual Studio 2022，并安装“使用 C++ 的桌面开发”
- Git

### 运行

```powershell
git clone https://github.com/nina27486486/weila.git
cd weila
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

项目路径建议使用纯英文，MobX 与 Hive 的代码生成工具在部分中文路径下可能无法正常
工作。

### 验证

```powershell
dart analyze
flutter test --no-pub
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_windows_release.ps1
```

Release 目录位于 `build/windows/x64/runner/Release/`，可分发压缩包位于
`build/windows/x64/runner/weila-<version>-windows-x64.zip`。Windows 应用依赖同
目录中的 DLL 与 `data/`，不能只复制 `weila.exe`。构建脚本使用临时英文路径规避
Flutter/MSBuild 在中文目录下的路径解析问题，校验 media_kit 原生依赖，并将许可与
版本说明一同打包。

## 播放器快捷键

| 按键 | 操作 |
|---|---|
| `Space` | 播放 / 暂停 |
| `←` / `→` | 后退 / 前进 5 秒 |
| `↑` / `↓` | 调整音量 |
| `D` | 显示 / 隐藏弹幕 |
| `F` | 进入 / 退出全屏 |
| `/` | 打开快捷键面板 |
| `Esc` | 关闭面板或退出全屏 |

## 技术架构

| 领域 | 技术 |
|---|---|
| 桌面 UI | Flutter Material 3、ViraColors ThemeExtension |
| 状态管理 | MobX |
| 路由与模块 | flutter_modular |
| 视频播放 | media_kit |
| 本地存储 | Hive CE |
| 网络与解析 | Dio、HTML、XPath、XML |
| 图片缓存 | cached_network_image、flutter_cache_manager |

```text
lib/
├── pages/       页面与页面级组件
├── widgets/     可复用界面组件
├── stores/      MobX 状态
├── services/    网络、插件、存储、弹幕与下载
├── models/      Hive 与业务模型
├── theme/       深浅主题与语义颜色
└── utils/       动画、日志和通用工具
```

## 数据与隐私

薇拉不提供账号系统。观看历史、收藏、追番、设置和弹幕凭据保存在本机 Hive 数据库中。
应用会按功能需要访问 Jikan、Bangumi、弹弹 play 以及用户启用的插件服务；这些服务
拥有各自的隐私政策和可用性边界。

请勿在 Issue、日志或截图中提交 API 密钥、个人目录、Cookie 或其他敏感信息。

## 项目边界

薇拉不托管视频、番剧封面或元数据，也不隶属于任何内容平台。播放链接由用户配置或
第三方插件提供，项目无法保证第三方内容的合法性、准确性与持续可用性。请仅访问
你有权使用的内容，并遵守所在地法律与内容服务条款。

项目的产品与架构思路受到
[Kazumi](https://github.com/Predidit/Kazumi) 启发，薇拉是独立开发的应用。

## 参与贡献

提交问题或代码前请阅读 [贡献指南](CONTRIBUTING.md) 与
[安全策略](SECURITY.md)。当前路线与已知限制见 [ROADMAP.md](ROADMAP.md)，版本变化
见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

本项目采用 [GNU General Public License v3.0 only](LICENSE) 发布。
