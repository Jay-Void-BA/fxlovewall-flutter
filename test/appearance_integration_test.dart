import 'dart:convert';

import 'package:campus_wall/data/appearance.dart';
import 'package:campus_wall/data/models.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/main.dart';
import 'package:campus_wall/state.dart';
import 'package:campus_wall/ui/appearance.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

class _AppearanceRepository extends WallRepository {
  int loads = 0;
  _AppearanceRepository() : super(cookieJar: CookieJar());
  @override
  Future<SiteDocument> load(String path) async {
    loads++;
    return parseDocument({'html': feedFixture, 'path': path});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('background seed drives light and dark themes on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'reduceMotion': true});
      final state = AppState(
        _AppearanceRepository(),
        await SharedPreferences.getInstance(),
      );
      await tester.pumpWidget(CampusWallApp(state: state));
      await tester.pumpAndSettle();
      await state.appearance.setBackground(WallBackground.forest);
      await state.appearance.setPalette(WallPalette.wallpaper);
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final seed = state.appearance.backgroundSeed;
      expect(
        app.theme!.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: seed).primary,
      );
      expect(
        app.darkTheme!.colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(app.theme!.scaffoldBackgroundColor, Colors.transparent);
      await state.setTheme(ThemeMode.dark);
      await tester.pumpAndSettle();
      final context = tester.element(find.text('说给\n校园听。'));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'adjusting overlay reuses themes, feed request and scroll position',
    (tester) async {
      SharedPreferences.setMockInitialValues({'reduceMotion': true});
      final repo = _AppearanceRepository();
      final state = AppState(repo, await SharedPreferences.getInstance());
      await state.appearance.setBackground(WallBackground.dawn);
      await state.appearance.setPalette(WallPalette.wallpaper);
      await tester.pumpWidget(CampusWallApp(state: state));
      await tester.pumpAndSettle();
      expect(repo.loads, 1);
      final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final controller = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      controller.jumpTo(40);
      await state.appearance.setOverlay(.65);
      await tester.pumpAndSettle();
      final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(identical(before.theme, after.theme), true);
      expect(identical(before.darkTheme, after.darkTheme), true);
      expect(repo.loads, 1);
      expect(
        identical(
          controller,
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .controller,
        ),
        true,
      );
      expect(controller.offset, 40);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'account opens appearance settings and keeps background after return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'reduceMotion': true});
      final state = AppState(
        _AppearanceRepository(),
        await SharedPreferences.getInstance(),
      );
      await tester.pumpWidget(CampusWallApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('背景与配色'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('背景与配色'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      final choice = find.byKey(const ValueKey('background-dusk'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(state.appearance.background, WallBackground.dusk);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsNothing);
      expect(state.appearance.background, WallBackground.dusk);
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .scaffoldBackgroundColor,
        Colors.transparent,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets('backgrounding the app flushes a pending overlay change', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reduceMotion': true});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(_AppearanceRepository(), prefs);
    await tester.pumpWidget(CampusWallApp(state: state));
    await tester.pumpAndSettle();
    await state.appearance.setOverlay(.7);
    // No 300 ms debounce interval elapses before the platform suspends us.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      jsonDecode(prefs.getString(AppearanceSettings.preferenceKey)!)['overlay'],
      .7,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
