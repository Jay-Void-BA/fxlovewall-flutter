# 1.0.1 构建与交付记录

日期：2026-10-30 UTC。Flutter 3.47.9 / Dart 3.13.7，Linux x86_64，JDK 21，Android target SDK 36 / min SDK 24。

- Android release 三架构实际构建成功；20 项自动化测试、1 项显式真实网站联调、5 项原有界面 golden 对比测试通过。
- flutter analyze：No issues found。
- 版本：1.0.1+2。分架构 versionCode 由 Flutter 分别添加 ABI 编号。
- 三个 APK 均通过 apksigner verify，APK v2 签名。测试证书与 1.0.0 相同，可作为该测试版的升级安装包。
- APK 身份 / 版本 / 原生 ABI 已检查；测试账号、Cookie、密码和签名私钥均未打包进源码归档或 APK。
- 默认完整测试会跳过显式开启的真实网络测试和 5 张预览。上述网络与 golden 测试分别另行开启且通过。
- 优化细节和响应量测量见 OPTIMIZATION_REPORT.md。没有进行实际设备帧率、功耗、系统分享或 UIKit Liquid Glass 实机验证。

## 安装包

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| fxwall-1.0.1-arm64-v8a.apk | 21046732 | `ccb1b91e454ba52a542f531429a0154d88a248b3335ba7be0b3d051ce5ee8349` |
| fxwall-1.0.1-armeabi-v7a.apk | 18777384 | `44eb7f5165ecd6b605274c6115bd5002dfe6fde35a3acc34e5075fcf34717e14` |
| fxwall-1.0.1-x86_64.apk | 22603728 | `bcbb52cf5474ee2d23b3c40b7fd0912fb14aaf79692aa494d28621b77686dcc5` |

## iOS / IPA

当前 Linux 的 Flutter SDK 不提供 iOS 构建目标，没有 Xcode / iOS SDK，不能从这里直接生成完整且可验证的 IPA。已实际执行命令；原始 ios-cross-build.log 保存在构建工作区，未纳入源码仓库。SDK 的 build_ios.dart 亦明确只支持 macOS。

源码增加 macOS 上的 unsigned-ipa 打包命令，以及对应 GitHub Actions macOS job；均需要真正使用 Xcode 编译 .app 后才打包。没有连接并执行远程 macOS CI，没有生成、上传或冒充 IPA。未签名 IPA 即使在 Mac 上编译成功，安装前也仍需有效签名。

历史 1.0.0 报告保存在 docs/history/1.0.0/，不代表本次新构建。
