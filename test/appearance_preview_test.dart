// Generate synthetic-data layout previews:
// flutter test test/appearance_preview_test.dart \
//   --dart-define=GENERATE_APPEARANCE_PREVIEWS=true --update-goldens
import 'dart:io';

import 'package:campus_wall/data/appearance.dart';
import 'package:campus_wall/data/models.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/main.dart';
import 'package:campus_wall/state.dart';
import 'package:campus_wall/ui/appearance.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _generate = bool.fromEnvironment('GENERATE_APPEARANCE_PREVIEWS');

String _previewFeed() {
  final posts = [
    ('校园日常', '午后的阳光落在走廊里。\n今天也想把一点好心情分享给你。', 12, 3),
    ('一起出发', '操场的晚风刚刚好，放学后一起去散步吧！', 8, 2),
    ('小小心愿', '希望每个认真生活的人，都能收获属于自己的惊喜。', 16, 4),
  ];
  return '''<html><head><title>校园墙</title></head><body>
  <header><nav><a href="/login">登录</a></nav></header><main>
  ${[for (final (i, post) in posts.indexed) '''
  <article class="card post">
    <div class="post-meta"><strong>匿名 #${401 + i}</strong><span>2026-11-06 12:00:00</span></div>
    <div class="tags"><a class="tag" href="/?q=${post.$1}">#${post.$1}</a></div>
    <div class="post-content">${post.$2.replaceAll('\n', '<br>')}</div>
    <div class="post-actions"><div class="left-actions"><span>点赞 ${post.$3}</span></div>
    <div class="right-actions"><a href="/post/${401 + i}">评论 ${post.$4}</a></div></div>
  </article>'''].join()}
  </main></body></html>''';
}

class _PreviewRepository extends WallRepository {
  _PreviewRepository() : super(cookieJar: CookieJar());

  @override
  Future<SiteDocument> load(String path) async =>
      parseDocument({'html': _previewFeed(), 'path': path});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_generate) return;
    final fontPath =
        Platform.environment['FXWALL_PREVIEW_FONT'] ??
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';
    final font = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', '.SF Pro Text']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  for (final spec in [
    (
      name: 'appearance-phone',
      size: const Size(412, 1800),
      platform: TargetPlatform.android,
      background: WallBackground.dawn,
      dark: false,
      settings: true,
    ),
    (
      name: 'monet-tablet',
      size: const Size(1366, 1024),
      platform: TargetPlatform.iOS,
      background: WallBackground.forest,
      dark: true,
      settings: false,
    ),
  ]) {
    testWidgets('render ${spec.name}', (tester) async {
      debugDefaultTargetPlatformOverride = spec.platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = spec.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'reduceMotion': true,
        'glass': false,
        'theme': spec.dark ? 2 : 1,
      });
      final state = AppState(
        _PreviewRepository(),
        await SharedPreferences.getInstance(),
      );
      addTearDown(state.dispose);
      await state.appearance.setBackground(spec.background);
      await state.appearance.setPalette(WallPalette.wallpaper);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('appearance-capture'),
          child: CampusWallApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
      if (spec.settings) {
        tester
            .state<NavigatorState>(find.byType(Navigator).last)
            .push(
              MaterialPageRoute<void>(builder: (_) => const AppearancePage()),
            );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('appearance-capture')),
        matchesGoldenFile('../docs/previews/${spec.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }, skip: !_generate);
  }
}
