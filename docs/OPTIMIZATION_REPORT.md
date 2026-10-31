# 1.0.1 优化记录（2026-10-30）

本次修复集中在已有功能的请求量、阅读连续性和草稿可靠性，界面功能保持兼容。

| 问题 | 1.0.1 的处理 | 验证 |
| --- | --- | --- |
| 恢复登录时首页被销毁并再次加载 | 保持 FeedPage 实例，只有外部登录状态变化且现有页面状态过期时才刷新 | 回归测试确认启动只请求 1 次，退出后复用 ScrollController 并保留位置 |
| 编号 / 关键词页面先请求再重复请求同一列表 | FeedPage 直接接收已解析的 SiteDocument | 回归测试确认编号搜索只请求 1 次 |
| 点赞、收藏返回整个首页 | 使用网站实际表单的 next 字段返回单条编号结果，保留分享许可、评论数等卡片信息 | 真实服务器收藏切换并还原，验证结果仅包含目标帖子 |
| 卡片重建时重复解析富文本 | 只在卡片 HTML 改变时重新解析 TextSpan，主题变化复用解析结果 | 原有富文本 / 转义与布局测试通过 |
| 编辑器快速退出可能丢失最后半秒文字 | 内存草稿即时更新，退出和提交前落盘，日常输入保持 500 ms 防抖 | 回归测试在计时器触发前关闭页面，确认最后输入已保存 |
| 损坏或越界的主题设置造成启动异常 | 对持久化索引执行合法范围约束 | 越界设置启动回归测试通过 |

## 真实响应量

同一测试账号、同一网站、同一次联调中比较响应 HTML 的 UTF-8 字节数：

- 完整登录态首页：1,216,217 字节。
- 优化后的单条收藏返回页：14,262 字节。
- 本次响应量减少：98.83%。这不是网络传输压缩率、帧率或所有访问场景的固定收益。

测试只切换并还原一个收藏，本轮没有新增公开帖子、评论或举报。

## iOS / IPA 交叉编译结论

当前环境是 Linux x86_64，没有 xcodebuild、xcrun 和 Apple iOS SDK。实际执行 Flutter iOS release 命令不能使用该目标；当前 SDK 的 build_ios.dart 明确限定 supported = platform.isMacOS，且抛出 “Building for iOS is only supported on macOS.”。

Flutter 官方构建要求：
https://docs.flutter.dev/deployment/ios
https://docs.flutter.dev/platform-integration/ios/setup

因此无法在此环境直接交叉编译并验证本应用的完整 IPA。将源码或 Android 文件改后缀 / 压入 Payload 不能成为 iOS 应用。本次没有伪造 IPA。

已增加 `bash scripts/build_ios.sh unsigned-ipa`：在 macOS 上先用 Xcode 编译真实 arm64 iOS .app，再打包为未签名 IPA。未签名包安装前仍需用户自己的有效签名。`ipa` 模式用于已有签名配置的发行构建。

GitHub Actions 工作流已增加 macOS 的 `ios-unsigned-ipa` job，同时保留模拟器构建；工作流源码已提供，当前会话没有连接可执行该工作流的 GitHub 仓库 / macOS 构建机，也未运行远程 CI。因此网盘中不会包含未经实际构建的 IPA。

## 本轮验证

- `flutter analyze` 无问题。
- `flutter test`：20 项通过，实时测试和 5 张预览默认跳过。
- 显式启用实时测试：1 项通过，包含优化后的收藏返回页验证。
- Android release 在本机编译，三个 ABI 的结果见同目录构建报告与校验文件。
- iOS 原生代码、系统材质和真实设备帧率尚未验证，仍需 macOS / 设备检查。
