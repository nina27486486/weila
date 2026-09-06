# 薇拉 Android 运行验收报告（API 36 · 合并后复验）

更新日期：2026-09-06
分支：`codex/android-mvp`（合并 master 后 HEAD `ed1cf36`）
模拟器：`Weila_API_36_Google_APIs`（Pixel 7 档 · API 36 Google APIs x86_64 · 冷启动 `-no-snapshot-load`）
构建入口：`lib/main_android.dart` · debug APK

## 1. 结论速览

| 项目 | 结论 |
| --- | --- |
| 合并后静态检查与测试 | PASS（analyze 零问题，454 项测试全过，含窄屏 hero 回归） |
| Windows Release 回归 | PASS（同盘 ASCII junction，见 2.3 偏差记录） |
| Android debug APK 构建 | PASS（206,032,109 字节） |
| Task 3 两次零输入冷启动 | PASS（均为 `/` 首页，无崩溃/无溢出/无白屏） |
| Task 4 目录网络链路 | PASS（详情页解析出 CMS 真实线路与选集） |
| Task 4 Android 能力门控 | PASS（凭据"暂不可用"、下载区、插件编辑区均按门控隐藏） |
| Task 4 总体 | **BLOCKED** — 新增真实缺陷：设置页分段标签条在 Pixel 7 窄屏右溢出 18 像素 |

## 2. 构建回归

### 2.1 合并

master 17 笔提交（含 `improve/architecture-quality` 全部 16 笔）合入本分支，
合并提交 `ed1cf36`。冲突解决原则：保留本分支的平台能力门控与启动组合，
吸收 master 的全局错误兜底、store 单例化、路由常量、弹幕缓存独立 box。
`AppBootstrap` 各步独立降级、存储失败上抛进入降级页；顺序测试保持通过。

### 2.2 Android APK

- bytes：`206032109`
- SHA-256：`5BAF6E68FA06C34F1DCAC346AA4199A03BD567CA1A489F929F985EF3BE9C93B9`
- 设备安装后 `base.apk` 哈希与本地一致。

两个构建阻塞的恢复记录（未触碰任何仓库文件）：

1. 在 git-bash 中 `cd` 穿透 workspace junction 会被规范化为真实非 ASCII
   路径，触发 AGP 路径检查；构建必须在 PowerShell 内以 junction 路径为
   工作目录执行。
2. worktree `build/` 清理后丢失 media_kit 原生库缓存；4 个 libmpv
   `v1.1.7` JAR 已按上游 MD5 逐一校验恢复（arm64 原件本就有效；
   armeabi-v7a/x86_64/x86 经 GitHub 镜像代理下载并 MD5 匹配）。

### 2.3 Windows Release（偏差记录）

按批准计划使用 `D:\VeraMobile\Temp\weila_windows_build_src` junction 全新
构建在 cmake INSTALL 阶段失败：跨盘 junction（D:→C: 真实非 ASCII 路径）
下新生成缓存的 `cmake_install.cmake` include 解析失败。2026-08-12 的
历史 PASS 依赖预绑定缓存。本次改用同盘 ASCII junction
`C:\weila_android_build_src`（脚本默认模式）后完整 Release 构建通过。
该偏差与根因已记入 SDD 账本，建议后续把计划的 Windows 回归命令改为
同盘 junction。

## 3. 运行验收（合并后 APK）

证据目录：本轮 D 盘 acceptance run（`20260906-postmerge-api36`）。

### 3.1 Task 3 — 两次零输入冷启动：PASS

| 轮次 | LaunchState | TotalTime | 采集 | PID | 结论 |
| --- | --- | --- | --- | --- | --- |
| 第一次 | COLD | 4453ms | 15s PNG+XML | 3759 全程存活 | `/` 首页 |
| 第二次 | COLD（force-stop 后） | 3349ms | 10s PNG+XML | 4929 全程存活 | `/` 首页 |

- 两次截图均为首页：本周主映 hero（第二次封面完整加载）、立即播放/查看
  详情、选集指示器，无白屏、无 splash 残留、无 overflow 条。
- XML 均含"首页""搜索"，不含目录加载标记。
- UIAutomator 常规 dump 因持续动画无法 idle，全部按协议执行
  三动画参数备份→置零→dump→恢复→逐项复核（恢复后 1.0/1.0/未设置，
  与原值一致），PID 未变。
- 合并日志七项致命扫描（FATAL EXCEPTION / 包内 ANR / Unhandled
  Exception / FlutterError / 设备丢失 / RenderFlex / BOTTOM OVERFLOWED）
  全部零命中。

### 3.2 Task 4 — 目录网络链路与能力门控

**网络链路 PASS**：首页 hero 点击"查看详情"进入真实作品详情页（PID
4929 连续存活），页面完整渲染海报、日期/地区/集数芯片、评分、题材标签、
选集网格；CMS 检索真实返回线路（视频源 ffzy）与 10 集选集——目录/CMS
网络链路在 Android 上真实可用。详情页日志扫描六项全部零命中。
**2026-08-26 的详情页窄屏 hero 修复经真机复验确认生效**（历史 Task 4
阻塞项 `BOTTOM OVERFLOWED BY 275 PIXELS` 未再出现）。

**能力门控 PASS**：设置页 XML 校验——凭据状态为"暂不可用"（Android
安全存储门控生效）、下载区不存在（`downloads=false`）、插件编辑入口不
存在（`pluginEditing=false`）。

**总体 BLOCKED — 新增真实缺陷**：设置页分段标签条
（设置目录/01 外观/02 播放与弹幕/…/05 关于）在 Pixel 7 窄屏
右溢出 **18 像素**，截图中可见竖排黄黑 overflow 条（本轮 run 的
`task4-settings-20260906.png`）。全量 logcat 未捕获对应 Flutter 错误行，
以截图为首要证据。按计划纪律未做猜测性修复；下一步应为该具体缺陷
另立精确 TDD 修复计划（嫌疑范围：`settings_components` 分段标签条在
窄屏的横向滚动/等分策略），修复后再恢复 Task 4 的目录页遍历断言。

## 4. Git 边界审计

- 本次验收新增仓库文件仅本报告；SDD 账本更新均为 ignored 文件。
- 三份 Windows 生成文件差异保持未暂存；无推送、无打标签、无版本变更、
  无 Release。
- 计划勾选更新仅限本次实际执行的窄屏修复计划 Task 2 步骤。

## 5. 后续顺序

1. 设置页分段标签条 18px 右溢出的根因诊断与 TDD 修复计划（新缺陷）。
2. 修复后恢复主验收计划 Task 4 余项（发现页目录遍历断言）。
3. Task 5 脱敏报告终稿与 Git 边界终审。
