# 贡献指南

感谢你愿意帮助薇拉变得更可靠。Bug 修复、测试、文档、可访问性改进和数据源兼容性
反馈都很有价值。

## 开始之前

1. 搜索现有 Issue，避免重复提交。
2. Bug 请使用 Bug 模板，安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。
3. 大型功能先创建讨论 Issue，确认范围后再实现。

## 本地开发

```powershell
git clone https://github.com/nina27486486/weila.git
cd weila
flutter pub get
flutter run -d windows
```

推荐使用 Flutter stable，并将仓库放在纯英文路径中。

## 代码要求

- 用户可见文本使用中文。
- 桌面端可点击元素必须提供 hover 状态和 `SystemMouseCursors.click`。
- 页面颜色通过 ViraColors 或 AppTheme 获取，避免散落新的硬编码主题色。
- 不新增第三方 UI 库；引入其他依赖前需在 PR 中说明必要性和替代方案。
- 修改 MobX Store 或 Hive 模型时同步提交生成的 `.g.dart`。
- 网络、插件和播放器变更必须包含失败、超时或空数据路径。
- 不提交视频、缓存、用户数据、API 密钥、Cookie 或构建产物。

## 提交前检查

```powershell
dart format lib test
dart analyze
flutter test --no-pub
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_windows_release.ps1
```

PR 请保持单一目的，并说明：

- 改变了什么以及为什么
- 如何验证
- 是否影响数据迁移、网络请求或播放器
- UI 变更的深色/浅色截图

## Commit 建议

推荐使用简洁的 Conventional Commits：

```text
feat: 增加播放器线路切换
fix: 修复封面缓存未刷新的问题
test: 覆盖搜索空结果状态
docs: 更新 Windows 构建说明
```
