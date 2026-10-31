# 构建与验证记录

日期：2026-10-29 UTC。执行环境：Linux x86_64，2 vCPU，8 GiB 内存。

## 实际完成

- Flutter 3.47.9 stable，Dart 3.13.7，JDK 21.0.13，Android compile / target SDK 36，最低 Android SDK 24。
- `flutter analyze`：No issues found。
- `flutter test`：16 项通过；实时网络测试和 5 个预览测试默认按设计跳过。
- 显式启用的实时网站测试：1 项通过。包括真实会话登录、公开列表与详情、编辑器表单、我的投稿、举报表单读取、收藏切换并还原、暖心话、退出登录。
- 实时评论联调通过：在原网站客户端讨论帖 #225 发表一条明确自述为 ChatGPT 的兼容性测试评论，存在性检查避免重复提交。
- 额外测试投稿 #558：明确说明 ChatGPT 身份与测试用途，服务器返回投稿成功、待审核。未尝试绕过审核。
- 显式启用的 Flutter 渲染预览：5 项通过，包含 Android 手机、iOS 手机、iPad 横屏、深色模式与每日小签。预览使用真实公开 HTML 快照；iOS 字体为用于跨平台渲染检查的 Noto 字体。
- 最终命令：`flutter build apk --release --target-platform android-arm64,android-arm,android-x64 --split-per-abi`，成功。
- 三个 APK 均通过 `apksigner verify`（APK Signature Scheme v2），并通过 ZIP 内原生库架构核验。使用 Android Debug 测试证书签署 release 优化构建。
- Android Manifest 核验：应用名复兴校园墙、target SDK 36、min SDK 24、INTERNET、allowBackup=false、usesCleartextTraffic=false。未启用 debuggable。

## 安装包

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| fxwall-1.0.0-arm64-v8a.apk | 21046728 | `95fc345b41e128cca24018f7c70ba16b09a0f26127a493b42702696bb964d14b` |
| fxwall-1.0.0-armeabi-v7a.apk | 18777384 | `c970e74a8302ab2efa9962e15d87d130db22da114602b339e693795379272422` |
| fxwall-1.0.0-x86_64.apk | 22603728 | `ac8b44076583f2b7365e58503ba0675e4dcde4a7e62fc38d59954d0d229e8e72` |

优先安装 ARM64 版本；ARMv7 用于仍运行 32 位 Android 的设备，x86_64 用于 Intel / x86 Android 与模拟器。分架构 versionCode 由 Flutter 自动加上 ABI 编号。

## 验证边界

- 云环境没有 /dev/kvm。尝试的软件 Android 模拟器未完成可用于安装 / 启动检查的引导，因此本次不声明 Android 设备运行、Keystore 或系统分享已经过真机验证。
- iOS 工程的 Dart 层已参与静态与布局检查，Info.plist / Keychain entitlement 通过结构解析。当前 Linux 没有 Xcode，因此未编译 Swift / iOS .app / IPA，未进行 iPhone / iPad 真机测试。
- iOS 26 UIKit UIGlassEffect 桥接位于 `ios/Runner/AppDelegate.swift`；需要 Xcode 26 / Swift 6.2 和 iOS 26 验证实际材质。低版本系统提供 UIBlurEffect fallback。CI 工作流和 macOS 脚本已提供，但未声称远程 CI 已运行。
- 未进行真实设备帧时间或功耗 profiling，不承诺实测 60 / 120 fps。已采用后台解析、惰性列表、局部重绘和有限玻璃表面，后续可使用 `flutter run --profile` 在目标设备检查。
- 网站使用 HTML 表单；站点结构、权限与运营规则可能变化。举报提交未进行无事实依据的测试。

测试账号、密码、Cookie 与工具链不会包含在源码 ZIP 或 APK 中。
