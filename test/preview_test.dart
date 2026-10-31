// Generate reviewable Flutter-rendered images from an actual public HTML capture:
// FXWALL_PREVIEW_HTML=/path/to/public.html flutter test test/preview_test.dart \
//   --dart-define=GENERATE_PREVIEWS=true --update-goldens
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_wall/data/models.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/main.dart';
import 'package:campus_wall/state.dart';

class PreviewRepository extends WallRepository {
  final String capture;
  final String? daily;
  PreviewRepository(this.capture, this.daily) : super(cookieJar: CookieJar());
  @override
  Future<SiteDocument> load(String path) async => parseDocument({
    'html': path.startsWith('/daily') ? daily ?? capture : capture,
    'path': path,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String capture;
  String? daily;
  setUpAll(() async {
    if (!const bool.fromEnvironment('GENERATE_PREVIEWS')) return;
    capture = File(
      Platform.environment['FXWALL_PREVIEW_HTML']!,
    ).readAsStringSync();
    final dailyPath = Platform.environment['FXWALL_PREVIEW_DAILY'];
    if (dailyPath != null) daily = File(dailyPath).readAsStringSync();
    final fontPath =
        Platform.environment['FXWALL_PREVIEW_FONT'] ??
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';
    final font = File(fontPath).readAsBytesSync();
    for (final name in ['Roboto', '.SF Pro Text']) {
      final loader = FontLoader(name)
        ..addFont(Future.value(ByteData.sublistView(font)));
      await loader.load();
    }
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await cupertino.load();
  });
  for (final spec in [
    (
      name: 'android-phone',
      size: const Size(412, 915),
      platform: TargetPlatform.android,
      dark: false,
      tab: 0,
    ),
    (
      name: 'ipad-landscape',
      size: const Size(1366, 1024),
      platform: TargetPlatform.iOS,
      dark: false,
      tab: 0,
    ),
    (
      name: 'ios-phone',
      size: const Size(393, 852),
      platform: TargetPlatform.iOS,
      dark: false,
      tab: 0,
    ),
    (
      name: 'android-dark',
      size: const Size(412, 915),
      platform: TargetPlatform.android,
      dark: true,
      tab: 0,
    ),
    (
      name: 'daily-phone',
      size: const Size(393, 852),
      platform: TargetPlatform.iOS,
      dark: false,
      tab: 2,
    ),
  ]) {
    testWidgets('render ${spec.name}', (tester) async {
      debugDefaultTargetPlatformOverride = spec.platform;
      tester.view.physicalSize = spec.size;
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({
        'reduceMotion': true,
        'theme': spec.dark ? 2 : 1,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: CampusWallApp(
            state: AppState(PreviewRepository(capture, daily), prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (spec.tab == 2) {
        await tester.tap(find.text('今日小签').first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('../docs/previews/${spec.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }, skip: !const bool.fromEnvironment('GENERATE_PREVIEWS'));
  }
}
