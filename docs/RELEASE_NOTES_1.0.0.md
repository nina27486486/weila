# 薇拉 1.0.0

薇拉 1.0.0 是首个面向 Windows 10/11 x64 的正式版本，集中完成播放源与清晰度、
线路健康诊断、真实弹弹play弹幕、双目录分类浏览、凭据安全和 Windows 安装工程。

## 下载

- `weila-1.0.0-windows-x64-setup.exe`：每用户安装器，默认安装到
  `%LOCALAPPDATA%\Programs\Weila`。
- `weila-1.0.0-windows-x64.zip`：便携版，解压后运行 `weila.exe`。
- `SHA256SUMS.txt`：两个发布产物的 SHA-256 清单。

Windows 应用依赖同目录中的 DLL 与 `data/`，不能只复制 `weila.exe`。

## 主要变化

- 多线路、多清晰度播放选择和线路健康度。
- 首帧、重缓冲、自动恢复和失败类型诊断。
- 安全验收报告，可在正常播放和失败界面复制脱敏 JSON。
- 弹弹play真实弹幕、标题/季度匹配、候选选择和 seek 同步。
- 修复拖动进度条后历史弹幕集中涌现的问题。
- “发现动画 / 可播放片库”双目录及多维筛选。
- 弹弹play AppId/AppSecret 迁移至 Windows Credential Manager。
- 播放器和详情页控制器拆分，补充覆盖率与发布工程门槛。

## 未签名与 SmartScreen

本版本没有 Authenticode 代码签名证书。Windows 可能显示 Microsoft Defender
SmartScreen 提示。请只从本仓库的 GitHub Releases 下载，并在运行前核对 SHA-256。

## 校验下载

在下载目录打开 PowerShell：

```powershell
Get-FileHash -Algorithm SHA256 .\weila-1.0.0-windows-x64.zip
Get-FileHash -Algorithm SHA256 .\weila-1.0.0-windows-x64-setup.exe
Get-Content .\SHA256SUMS.txt
```

两个 `Get-FileHash` 结果必须与 `SHA256SUMS.txt` 完全一致；不一致时不要运行。

本次正式候选的预期值：

- ZIP：`d668de50da0fb6fd5ba1d6147da95278867d41f37d686850c50ef9fa720fc7ff`
- 安装器：`1a68a7828545c5502a85c7b2860a3677e6c9cd7a252687c688c462554e7d0a36`

## 手动更新

1. 关闭正在运行的薇拉。
2. 建议先备份 Hive 数据和下载目录。
3. 安装版直接运行新安装器覆盖安装；便携版解压到新目录，不要只替换 EXE。
4. 启动后检查收藏、历史、追番和弹幕服务连接状态。

安装器升级和卸载默认不删除 Hive、离线下载或 `Weila/Dandanplay` 安全凭据。

## 回滚

1. 关闭薇拉并备份当前 Hive 与下载目录。
2. 卸载 1.0.0 或移走便携目录。
3. 安装或解压上一稳定版本。
4. 如遇数据不兼容，再恢复升级前备份；不要用 Git 或安装脚本覆盖用户数据。

## 验收与已知风险

- 中国大陆网络矩阵：樱花 6/6、非凡 6/6。
- 弹弹play真实签名搜索与弹幕获取测试通过。
- 当前账户覆盖安装、界面启动、业务数据和弹幕凭据保留通过。
- 干净 Windows 首次安装/卸载、下载与凭据卸载保留、SmartScreen/快捷方式未完成
  独立验证；维护者已明确接受该发布风险。
- 第三方目录、视频和弹幕服务可能因地区、限流、下架或接口变化而不可用。

完整变更见 `CHANGELOG.md`，隐私与本地数据说明见 `PRIVACY.md`。
