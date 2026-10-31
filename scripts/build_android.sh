#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
printf 'APK: %s/build/app/outputs/flutter-apk/\n' "$PWD"
