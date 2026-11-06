# 复兴校园墙 · Flutter 1.1.0

[![平台构建](https://github.com/Jay-Void-BA/fxlovewall-flutter/actions/workflows/build.yml/badge.svg)](https://github.com/Jay-Void-BA/fxlovewall-flutter/actions/workflows/build.yml)

面向 https://fxlovewall.me/ 的独立 Android / iOS 客户端。手机底部导航、平板侧栏、宽屏帖子与评论双栏。内容和账号使用原网站服务，不需要新建后端。

本版新增更换背景和背景莫奈取色，可在「我的 → 背景与配色」设置。详见 [1.1.0 更新说明](docs/RELEASE_1.1.0.md)。此前的请求量、滚动位置与草稿优化见 [1.0.1 优化报告](docs/OPTIMIZATION_REPORT.md)。

## 下载与预览

新版外观预览：[手机背景与配色设置](docs/previews/appearance-phone.png) · [平板深色莫奈主题](docs/previews/monet-tablet.png)。预览使用合成示例内容。

[GitHub Releases 最新正式版](https://github.com/Jay-Void-BA/fxlovewall-flutter/releases/latest)：Android 三架构 APK、iOS 未签名 IPA、iOS 模拟器包及 SHA-256 校验文件。新版本在 CI 构建和发布校验成功后才会出现在这里，具体版本以 Release 标签为准。普通 Android 手机和平板请选择 `arm64-v8a.apk`；iPhone / iPad 的 IPA 需要自行签名后安装。

[此前的 Google Drive 交付文件](https://drive.google.com/drive/folders/1ibPpFS3dqHk0I_p2fR3GvVe4fmaUWgz1)需要有权访问该文件夹的账号，与 GitHub CI 的测试签名可能不同。

| Android | iOS 布局预览 |
| --- | --- |
| ![Android 首页](docs/previews/android-phone.png) | ![iOS 首页布局](docs/previews/ios-phone.png) |

![平板双栏布局](docs/previews/ipad-landscape.png)

以上为经典外观的历史布局预览。背景与配色可在应用内实时预览。

## 功能

- 最新 / 最热、标签 / 关键词 / 帖子编号搜索、随机帖子、下拉刷新。
- 完整文字样式、帖子详情、评论阅读与发表、点赞、网站账号收藏、帖子与评论举报。
- 登录、注册、我的投稿、审核状态、评论提醒、我的收藏、退出登录。
- 原生投稿编辑器：斜体、四种文字颜色、最多 3 个标签、分享许可；本机自动保存草稿。
- 恋爱运、暖心话、幸运物品；结果与每日限额由原网站决定。
- 入站须知、知识栏目、网站隐私与内容合规声明。
- 系统 / 浅色 / 深色主题、减少动态效果、公开帖子离线阅读缓存。
- 经典底色、晨曦 / 森林 / 暮色渐变和相册背景照片；阅读柔化强度、照片删除与一键重置。
- 系统动态配色、背景莫奈取色、八种自选主题色；背景与配色选择保存在本机。

网站投稿原本不提供图片，也不提供私信、密码找回等功能，本客户端保持网站的能力范围。投稿仍需管理员审核。

## 背景与莫奈取色

打开「我的 → 背景与配色」，选择内置背景，或点「从相册选择背景」。选图取消或处理失败时保留原背景；已保存的照片可删除。阅读柔化用于降低背景对文字的干扰，系统高对比度模式使用实色背景。

在「主题配色」选择「背景莫奈取色」，即可从当前背景生成协调的按钮、标签和主题色；浅色与深色模式使用同一个取色种子分别生成配色。内置渐变使用对应的预设种子，照片使用图片内容提色。选择「自选主题色」可使用八种预设颜色；「跟随系统」在 Android 12+ 使用系统提供的动态配色，其他系统使用默认配色。

背景照片仅保存在应用私有目录，不会上传。导入时将图片归一化为最长边不超过 1600 像素的 PNG，并去除原照片元数据；提色在最长边 112 像素的样本上进行。设置保存在本机，Android 在选图期间被系统回收后会尝试恢复选择结果。重新选择照片、删除照片或恢复默认设置都在这个页面完成。

## 两个平台

Android 使用 Flutter Material 3、Android 12+ 系统动态配色、预测返回动画和自适应导航，目标 SDK 36。最低系统版本由 Flutter / 插件要求决定（当前 Android 7.0+）。

iOS 使用 Cupertino 图标、iOS 页面转场、触感反馈、浮动玻璃导航，支持 iPhone / iPad 和横竖屏。Xcode 26 / Swift 6.2 构建时，iOS 26+ 通过平台视图接入真正的 UIKit `UIGlassEffect`；旧系统回退到 `systemUltraThinMaterial`。系统高对比度时使用实色导航；减少动态效果时关闭模糊和平台视图材质。最低 iOS 15。

1.0.1 的 Android APK 已在 Linux 实际编译；iOS 模拟器 .app 和未签名真机 IPA 已在 GitHub macOS / Xcode 26 运行器实际编译成功。[首次通过的完整 CI](https://github.com/Jay-Void-BA/fxlovewall-flutter/actions/runs/41162105609)包含 Android 检查 / 构建与两个 iOS 构建任务。1.1.0 的实际结果以对应 Actions 运行和 Release 构建报告为准。iOS 玻璃截图仍为 Flutter 布局预览，尚未进行 iOS 26 实机材质或帧率验证。

iOS 选择背景照片使用系统相册选择器，工程包含照片访问用途说明；背景图片和莫奈取色均在设备本地处理。

## 构建

开发使用 Flutter 3.47.9 / Dart 3.13.7、JDK 21、Android SDK 36 / NDK 28.2。依赖锁定在 `pubspec.lock`。

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Android：

```sh
bash scripts/build_android.sh
# 或只构建 ARM64
flutter build apk --release --target-platform android-arm64
```

交付的 APK 是 release 优化构建，使用测试签名。上架前在 `android/key.properties` 配置自己的发行签名；示例见 `android/key.properties.example`。不要提交私钥或密码。

macOS / Xcode：

```sh
bash scripts/build_ios.sh simulator  # 模拟器 .app，无需开发者证书
bash scripts/build_ios.sh device     # 未签名真机 .app
bash scripts/build_ios.sh unsigned-ipa  # macOS 上编译后打包未签名 IPA
# 在 Xcode 中设置 Team、Bundle ID 和 provisioning profile 后：
bash scripts/build_ios.sh ipa
```

## GitHub Actions

推送 `main`、提交 Pull Request 或在 Actions 页面手动运行 `Flutter checks and platform builds`，会执行 Android 检查 / APK 构建，以及 macOS / Xcode 26 上的 iOS 模拟器和未签名 IPA 构建。成功的任务会在该次运行的 Artifacts 中保存产物；具体结果以运行状态为准。

主分支完整构建成功后，`Publish verified build artifacts` 会验证构建来源、三个任务状态、包结构、iOS 版本与 Android 签名，并发布对应版本的 GitHub Release。相同版本的已发布资产不会被自动覆盖；发布新版本前需增加 `pubspec.yaml` 版本号。也可手动运行发布工作流，指定已成功的主分支 build run ID。Release 标签指向产物实际构建的提交。

Android CI 未配置发行签名时会使用运行器生成的测试密钥，因此不同运行的 APK 不保证能够互相覆盖安装，也不保证能覆盖 Google Drive 的测试版。正式发布应使用固定的发行签名。iOS 未签名 IPA 必须签名后才能安装。

仓库保留源代码、依赖锁文件、平台工程、测试、构建脚本和报告；生成缓存、安装包、测试凭据和签名私钥由 `.gitignore` 排除。安装包通过 Actions Artifacts 或交付下载链接获取。

## 结构与性能

`lib/data` 解析真实服务器 HTML 和表单，Dio 负责 HTTPS、受限同源跳转、CSRF 与会话；Cookie 存放于系统安全存储，不保存登录密码。公开内容使用 SharedPreferences 缓存，缓存排除 CSRF、Cookie、私有投稿、用户收藏状态和评论。

`lib/ui` 是原生 Flutter 组件，没有整站 WebView。首页 HTML 解析通过 `compute` 在后台 isolate 执行，长列表按需构建，卡片使用 `RepaintBoundary`，首页不生成未使用的通用 HTML 表单树。玻璃效果仅用于少量导航 / 装饰区域，不覆盖每张滚动卡片。转场遵循平台及系统减少动画设置。

`lib/data/appearance.dart` 管理外观设置、私有背景文件与图片提色。照片通过 Material Color Utilities 的 `QuantizerCelebi` 和 `Score` 在后台 isolate 量化与选色，再由 `ColorScheme.fromSeed` 生成 Material 3 明暗配色。背景作为导航器下方的静态绘制层，不随列表滚动，不增加全屏实时模糊；阅读柔化调整复用现有主题，不重复生成色板。

网站采用服务端网页表单，没有公开 JSON API；页面结构变更后，可能需要维护 `models.dart` 的选择器。无法仅凭构建和布局测试证明具体设备上的 60/120 fps；正式发布前应在 Android / iPhone / iPad 上用 profile 模式检查滚动、转场、键盘、系统分享和玻璃合成。

## 验证

自动化测试覆盖重复请求、滚动位置保留、快速退出草稿、公开 / 登录态解析、CSRF / 分享许可、缓存隔离、编辑器样式与转义、登录跳转、同源限制、错误提示、手机 / 平板布局和原生投稿表单。1.1.0 增加外观设置持久化、损坏数据修复、选图取消 / 失败回滚、照片处理、背景与配色交互及自适应布局测试；实际通过情况以测试输出和对应 CI 记录为准。实时网站测试默认跳过，需要显式启用并提供不打包进应用的本地测试凭据：

```sh
FXWALL_TEST_CREDENTIALS=/private/test-account.json \
  flutter test test/live_site_test.dart --dart-define=RUN_LIVE=true
```

凭据文件格式：`{"username":"...","password":"..."}`。测试默认只验证已有账号，收藏切换会恢复原状态。公开评论必须另外设置 `FXWALL_TEST_PUBLISH_COMMENT=true`，内容明确自述为 ChatGPT，并检查是否已存在以避免重复发表。不会自动注册账号或提交举报。

早期联调账号包含 ChatGPT 名称；测试投稿 #558 明确说明 ChatGPT 身份与兼容性测试用途，当时服务器返回待审核。客户端中不内置测试账号、密码、Cookie 或测试投稿内容。

布局预览位于 `docs/previews/`，由 Flutter 测试渲染器读取真实公开页面快照生成；Android 动态配色与 iOS 系统材质应以设备为准。
