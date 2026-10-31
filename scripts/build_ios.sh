#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  printf 'iOS 编译需要安装 Xcode 的 macOS；当前系统无法执行。\n' >&2
  exit 1
fi
xcodebuild -version
flutter pub get
case "${1:-simulator}" in
  simulator) flutter build ios --simulator --debug --no-codesign ;;
  device) flutter build ios --release --no-codesign ;;
  unsigned-ipa)
    flutter build ios --release --no-codesign
    ios_package_dir="$(mktemp -d)"
    trap 'rm -rf "$ios_package_dir"' EXIT
    mkdir -p "$ios_package_dir/Payload" build/ios/ipa
    ditto build/ios/iphoneos/Runner.app "$ios_package_dir/Payload/Runner.app"
    ios_package_version="$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)"
    ditto -c -k --keepParent "$ios_package_dir/Payload" "build/ios/ipa/fxwall-$ios_package_version-unsigned.ipa"
    printf '已打包未签名 IPA；安装前仍需使用自己的证书进行签名。\n'
    ;;
  ipa) flutter build ipa --release ;;
  *) printf '用法: scripts/build_ios.sh [simulator|device|unsigned-ipa|ipa]\n' >&2; exit 2 ;;
esac
