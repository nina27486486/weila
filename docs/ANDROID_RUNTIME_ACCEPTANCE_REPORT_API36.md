# 薇拉 Android API 36 运行验收报告

更新日期：2026-09-06
分支：`codex/android-mvp`（master 合并后 HEAD `ed1cf36`，另有验收期修复提交 `5629799`）

## 范围与结论

本报告只覆盖应用壳、首页信息流网络链路、目录/详情网络链路、
页面窄屏布局与 Android 能力门控。播放、弹幕渲染、真实凭据、下载、
签名与发布不在本阶段验收范围内（同主验收计划的阶段边界）。

## 环境

事实来源：`device.txt`（取自 AVD config）。

- AVD：`Weila_API_36_Google_APIs`
- API：36，ABI：x86_64
- 机型档案：pixel_7，分辨率 1080x2400，密度 420
- 启动方式：可见窗口、`-no-snapshot-load` 冷启动

## 构建产物

事实来源：`apk.txt`。

- 合并后首版 debug APK：206032109 字节，
  SHA-256 `5BAF6E68FA06C34F1DCAC346AA4199A03BD567CA1A489F929F985EF3BE9C93B9`，
  设备安装后 base.apk 哈希与本地一致。
- 窄屏修复版 debug APK（提交 `5629799` 后）：206032109 字节，
  SHA-256 `FEB308AAA7551090224BD0C5159BB51752DA8340477481573E89C312F50B645B`，
  设备安装后 base.apk 哈希与本地一致。

## 启动稳定性

事实来源：`first-launch.txt`、`second-launch.txt`、`startup-signal-scan.txt`
（两轮截图与 UI hierarchy：`task3-first-20260906.png/xml`、
`task3-second-20260906.png/xml`）。

| 轮次 | 状态 | LaunchState | TotalTime | 进程 |
| --- | --- | --- | --- | --- |
| 第一次零输入冷启动 | ok | COLD | 4453ms | 存活贯穿采集 |
| 第二次（force-stop 后）零输入冷启动 | ok | COLD | 3349ms | 存活贯穿采集 |

两轮截图均为 `/` 首页（本周主映 hero、立即播放/查看详情、章节选择器），
无白屏、无 splash 残留、无 overflow 条。UIAutomator 常规 dump 因持续
动画无法 idle，均按协议备份三动画参数→置零→dump→恢复→逐项复核，
恢复值与原值一致，进程未变。合并日志七项致命扫描
（FATAL EXCEPTION / 包内 ANR / Unhandled Exception / FlutterError /
设备丢失 / RenderFlex / BOTTOM OVERFLOWED）全部零命中。

## 页面与网络链路矩阵

事实来源：下列证据文件 basename（均在本地证据目录）。

| 页面/路径 | 结果 | 证据 |
| --- | --- | --- |
| 首页 `/`（信息流网络链路） | 通过 | `task3-first-20260906.png`、`task3-second-20260906.png`（hero 真实数据与封面） |
| 详情（首页 hero 进入，CMS 链路） | 通过 | `task4-detail-20260906.png/xml`（真实线路"视频源 ffzy"与 10 集选集） |
| 设置（章节索引窄屏布局） | 修复后通过 | 修复前 `task4-settings-20260906.png`（右溢出 18px）；修复后 `task4-settings-fixed-20260906.png`（无溢出） |
| 发现/目录（筛选维度遍历） | 通过 | `task4-discover-20260906.png/xml`（动画目录、双标签、题材/年份芯片完整） |
| 搜索"葬送的芙莉莲" | 本轮未执行 | 本轮计划范围未包含搜索遍历；历史基线记录见 2026-08-02 run |

## Android 能力门控

事实来源：`ui-assertions.txt` 及设置页证据。

- 凭据状态展示"暂不可用"：通过（Android 无安全凭据存储时的降级门控）。
- 下载区按能力隐藏：通过。
- 插件编辑入口按能力隐藏：通过。
- 修复后章节索引无水平溢出：通过。

## 故障与修复

本轮验收发现并按 TDD 修复一个真实缺陷，未做任何猜测性修改：

- 缺陷：设置页章节索引条在 Pixel 7 窄屏右溢出 18 像素（修复前证据
  `task4-settings-20260906.png`）。
- 根因：章节项在 `Expanded` 槽位内放置不可收缩的"序号 + 标签"行，
  最宽标签超出窄屏槽位。
- 修复：标签改为 `Flexible` + 单行省略（桌面视觉不变），提交
  `5629799`，回归测试在 411px 宽度先 RED（19px）后 GREEN。
- 回归：修复版 APK 真机复验无溢出（`task4-settings-fixed-20260906.png`），
  全仓 455 项测试通过，静态检查零问题。

Windows 回归的构建环境偏差（非应用缺陷）：跨盘 junction 下全新缓存的
cmake INSTALL include 解析失败，改用同盘 ASCII junction 后构建通过；
已记入 SDD 账本，不涉及仓库文件。

## 安全与脱敏

原始证据（截图、UI hierarchy、完整日志、哈希清单）只保存在本地验收
证据目录，仓库只保留本报告。Cookie 与凭据已脱敏；报告不包含 Header、
AppId、AppSecret、ProxyAuthorization 或完整媒体 URL。

## 已验证、未验证与风险

已验证：应用壳两次冷启动稳定；首页信息流与目录/详情 CMS 网络链路在
模拟器真实可用；窄屏布局经三处缺陷修复（首页 hero、详情页 hero、
设置页章节索引）后主要页面无溢出；能力门控按预期生效。

未验证：签名与发布；搜索页遍历留待后续阶段。视频播放与实体手机项
已由下方实机验收首轮覆盖。

风险：目录索引计数在本轮显示为初始状态，目录数据的完整聚合需要更长
网络窗口确认；窄屏布局仍有未巡检页面。

## 实机验收首轮（vivo V2505A · Android 16 · arm64-v8a）

事实来源：本地证据目录 `20260906-device-v2505a`（device.txt、
lifecycle-results.txt 与截图序列）。

设备：vivo V2505A，Android 16（API 36），arm64-v8a，
1440x3168 @640dpi（逻辑宽度 360dp），字体缩放 1.0。

- 安装：universal debug APK（修复版，哈希一致）；vivo USB 安装提示由
  主人手动允许。
- 冷启动：通过——COLD 1141ms，进程 2650 全程存活。
- 后台返回：通过——HOT 103ms，同进程恢复。
- 锁屏唤醒：通过（vivo 锁屏需主人手动解锁，进程存活）。
- 旋转：浏览态竖屏锁定符合计划 §4 设计；旋转尝试中进程稳定。
- 真实播放：通过——media_kit 在 arm64 真机解码真实 CMS HLS 流，
  画面跨截图持续推进，OpenSL ES 音频播放器激活（USAGE_MEDIA），
  纯黑舞台与信箱式画幅符合设计。
- 播放中后台返回：通过——HOT 55ms，返回后播放继续。
- 致命日志扫描：仅命中其他应用的历史旧记录；薇拉零命中。

新发现：刊头在 360dp 逻辑宽度右溢出 14 像素（`dev-first-launch.png`）
——窄屏家族第 4 例，也是 MVP 计划要求的 360 档首次实测；需另立精确
TDD 修复计划。

待主人协助项：播放中锁屏恢复（需手动解锁）、音频中断（需第二音频源
或来电）、播放控制层自动隐藏手感确认。

## Git 边界

本报告提交前未 push、未 merge、未升版、未打标签、未创建 Release；
三份 Windows 生成文件保持未暂存；本地证据目录、SDD 账本与
`android/local.properties` 均不进入 Git。
