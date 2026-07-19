# AGENTS.md

## 用户称呼与沟通

- 始终称呼用户为“主人”。
- 默认使用中文回复，语气可以温暖、直接、有主见，但不要空泛夸赞。
- 工具操作前先用简短中文说明要做什么；长任务期间保持进度更新。
- 最终回复要自包含，说明改了什么、验证了什么、还有什么风险。

## 项目背景

- 项目名：薇拉 / Weila。
- 类型：Flutter Windows 桌面端动画追番、发现、播放、弹幕、收藏历史和离线缓存应用。
- 当前视觉方向：“天空日记 × 动漫杂志”，包含看板娘、液态玻璃、动漫卡片、海报轨道和纸张/墨迹纹理。
- 当前重点不只是美术，朋友反馈集中在播放慢、清晰度不可切换、弹幕不完整、分类浏览维度少。
- 新对话接手时先阅读 `PROJECT_HANDOFF.md`。

## 工作区安全规则

- 这是一个脏工作区，存在大量未提交改动；不要使用 `git reset --hard`、`git checkout --` 或任何会丢弃改动的命令，除非主人明确要求。
- 修改前先看 `git status --short --branch`，理解已有改动属于谁。
- 不要随意重排无关文件、格式化全仓或改动生成文件，除非任务需要。
- 手写代码修改使用 `apply_patch`。
- 搜索文件优先使用 `rg` 或 `rg --files`。
- 不要在未完成验证前声称“已完成”“已修复”“可发布”。

## 工程约束

- 保持 Flutter 原生实现，不复制外部 React/网页源码。
- 默认不引入第三方取色、UI 或素材依赖，除非主人确认。
- 共享视觉组件应尽量只接收展示数据和回调，不直接依赖 MobX。
- 不要随意改 Store、Service、路由、网络接口和本地数据格式；需要改时先说明影响面。
- 所有持续动画要考虑 `TickerMode`、应用生命周期和 `MediaQuery.disableAnimations`。
- 播放器视频舞台保持纯黑，避免环境背景干扰视频内容。
- Windows Release 构建要注意中文路径问题，优先使用项目已有脚本 `tool/build_windows_release.ps1`。

## 当前优先级

1. 播放源与清晰度模型：保留多线路、多清晰度，支持手动切换和自动健康度选择。
2. 播放性能诊断：记录 API、manifest、首帧、重缓冲、失败原因。
3. 弹幕真实化：去掉 Release 测试弹幕兜底，加入匹配、状态、过滤和全局代理。
4. 分类浏览升级：建立稳定内容 ID、元数据索引和多维筛选。
5. 继续瘦身 `player_page.dart`、`detail_page.dart`，把控制逻辑和展示组件拆开。
6. Android 迁移放在播放/弹幕/分类模型稳定之后。

## 常用验证命令

```powershell
flutter analyze
flutter test
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_windows_release.ps1
```

必要时先运行：

```powershell
flutter pub get
```

## 交付习惯

- 每次改动后说明涉及文件和用户可见行为。
- 能跑测试就跑；不能跑要明确原因。
- 如果 staged、commit、push 成功，最终回复里按 Codex 桌面要求输出对应 git 指令标记。
- 未经主人确认，不要替主人提交、合并或推送。
