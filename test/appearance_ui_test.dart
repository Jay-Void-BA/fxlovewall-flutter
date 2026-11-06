import 'package:campus_wall/data/appearance.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/state.dart';
import 'package:campus_wall/ui/appearance.dart';
import 'package:campus_wall/ui/design.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> appearanceState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState(
    WallRepository(cookieJar: CookieJar()),
    await SharedPreferences.getInstance(),
  );
}

Widget appearanceHarness(
  AppState state, {
  bool highContrast = false,
  double textScale = 1,
}) => AppScope(
  state: state,
  child: ListenableBuilder(
    listenable: state.appearance,
    builder: (context, _) => MaterialApp(
      theme: wallTheme(
        Brightness.light,
        ColorScheme.fromSeed(
          seedColor: state.appearance.palette == WallPalette.custom
              ? state.appearance.customSeed
              : state.appearance.backgroundSeed,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          highContrast: highContrast,
          textScaler: TextScaler.linear(textScale),
        ),
        child: WallBackgroundLayer(child: child!),
      ),
      home: const AppearancePage(),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('background, Monet, custom color and reset work together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await appearanceState();
    addTearDown(state.dispose);
    await tester.pumpWidget(appearanceHarness(state));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    Future<void> reach(String key) async {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        260,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
    }

    await reach('background-forest');
    await tester.tap(find.byKey(const ValueKey('background-forest')));
    await tester.pumpAndSettle();
    expect(state.appearance.background, WallBackground.forest);
    expect(state.appearance.hasBackground, isTrue);

    await reach('background-overlay');
    await tester.drag(
      find.byKey(const ValueKey('background-overlay')),
      const Offset(65, 0),
    );
    await tester.pumpAndSettle();
    expect(state.appearance.overlay, greaterThan(.3));

    await reach('palette-wallpaper');
    await tester.tap(find.byKey(const ValueKey('palette-wallpaper')));
    await tester.pumpAndSettle();
    expect(state.appearance.palette, WallPalette.wallpaper);

    await reach('palette-custom');
    await tester.tap(find.byKey(const ValueKey('palette-custom')));
    await tester.pumpAndSettle();
    await reach('theme-color-蔷薇粉');
    await tester.tap(find.byKey(const ValueKey('theme-color-蔷薇粉')));
    await tester.pumpAndSettle();
    expect(state.appearance.palette, WallPalette.custom);
    expect(state.appearance.customSeed, const Color(0xFFBE6686));

    await reach('reset-appearance');
    await tester.tap(find.byKey(const ValueKey('reset-appearance')));
    await tester.pumpAndSettle();
    expect(state.appearance.background, WallBackground.classic);
    expect(state.appearance.palette, WallPalette.system);
    expect(state.appearance.hasBackground, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(320, 720),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1366, 1024),
  ]) {
    testWidgets('appearance settings fit ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await appearanceState();
      addTearDown(state.dispose);
      await state.appearance.setBackground(WallBackground.dusk);
      await state.appearance.setPalette(WallPalette.custom);
      await tester.pumpWidget(appearanceHarness(state));
      await tester.pumpAndSettle();
      expect(find.text('背景与配色'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reset-appearance')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reset-appearance')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scale in [1.6, 2.0]) {
    testWidgets('appearance remains readable with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await appearanceState();
      addTearDown(state.dispose);
      await state.appearance.setBackground(WallBackground.forest);
      await state.appearance.setPalette(WallPalette.custom);
      await tester.pumpWidget(appearanceHarness(state, textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reset-appearance')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('high contrast uses a solid background behind the navigator', (
    tester,
  ) async {
    final state = await appearanceState();
    addTearDown(state.dispose);
    await state.appearance.setBackground(WallBackground.dawn);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: wallTheme(Brightness.light, null),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: WallBackgroundLayer(child: child!),
          ),
          home: const Scaffold(body: Text('页面内容')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('页面内容'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    final paint = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is RepaintBoundary && widget.child is ColoredBox,
      ),
      matching: find.byType(ColoredBox),
    );
    expect(paint, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
