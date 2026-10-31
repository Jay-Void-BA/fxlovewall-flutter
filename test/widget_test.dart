import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_wall/main.dart';
import 'package:campus_wall/state.dart';
import 'package:campus_wall/data/models.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/ui/forms.dart';
import 'package:campus_wall/ui/design.dart';
import 'fixtures.dart';

class FixtureRepository extends WallRepository {
  FixtureRepository() : super(cookieJar: CookieJar());
  @override
  Future<SiteDocument> load(String path) async => parseDocument({
    'html': path.startsWith('/post/')
        ? detailFixture
        : path.startsWith('/login')
        ? loginFixture
        : feedFixture,
    'path': path,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(844, 390),
    const Size(1366, 1024),
  ]) {
    testWidgets('adaptive layout ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        CampusWallApp(state: AppState(FixtureRepository(), prefs)),
      );
      await tester.pumpAndSettle();
      expect(find.text('说给\n校园听。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width >= 1050) {
        expect(find.text('今天，也要开心。'), findsOneWidget);
      }
      await tester.tap(
        size.width >= 720 && size.height >= 600
            ? find.byTooltip('发现')
            : find.text('发现').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('发现一点新鲜事'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('iOS glass navigation respects reduced motion', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'reduceMotion': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      CampusWallApp(state: AppState(FixtureRepository(), prefs)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'native composer validates content and submits checkbox semantics',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final spec = parseDocument({
        'html': composeFixture,
        'path': '/post/new',
      }).forms.single;
      Map<String, String>? submitted;
      await tester.pumpWidget(
        AppScope(
          state: AppState(FixtureRepository(), prefs),
          child: MaterialApp(
            theme: wallTheme(Brightness.light, null),
            home: Scaffold(
              body: SingleChildScrollView(
                child: NativeForm(
                  spec: spec,
                  onSubmit: (v) async {
                    submitted = v;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('提交投稿'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      await tester.enterText(find.byType(TextFormField).first, '你好校园');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('提交投稿'));
      await tester.tap(find.text('提交投稿'));
      await tester.pumpAndSettle();
      expect(submitted!['content_html'], '你好校园');
      expect(submitted!.containsKey('allow_share'), false);
      expect(submitted!['csrf_token'], 'fixture-token');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
