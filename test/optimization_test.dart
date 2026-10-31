import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_wall/main.dart';
import 'package:campus_wall/data/models.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/state.dart';
import 'package:campus_wall/ui/design.dart';
import 'package:campus_wall/ui/forms.dart';
import 'package:campus_wall/ui/pages.dart';
import 'fixtures.dart';

class CountingRepository extends WallRepository {
  int loads = 0;
  bool authenticated;
  CountingRepository({this.authenticated = false})
    : super(cookieJar: CookieJar());
  @override
  Future<SiteDocument> load(String path) async {
    loads++;
    return parseDocument({
      'html': authenticated ? authFeedFixture : feedFixture,
      'path': path,
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'restored login loads the feed once and logout preserves its controller',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CountingRepository(authenticated: true);
      final state = AppState(repository, prefs);
      await tester.pumpWidget(CampusWallApp(state: state));
      await tester.pumpAndSettle();
      expect(state.signedIn, true);
      expect(repository.loads, 1);
      final controller = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      controller.jumpTo(50);
      repository.authenticated = false;
      await state.signOut();
      await tester.pumpAndSettle();
      expect(repository.loads, 2);
      final after = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      expect(identical(controller, after), true);
      expect(after.offset, 50);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a numbered search reuses its already loaded server response', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = CountingRepository();
    await tester.pumpWidget(
      AppScope(
        state: AppState(repository, prefs),
        child: MaterialApp(
          theme: wallTheme(Brightness.light, null),
          home: const SitePage(path: '/?q=42'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.loads, 1);
    expect(find.text('匿名 #42'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving within the debounce interval saves the latest draft', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(CountingRepository(), prefs);
    final spec = parseDocument({
      'html': composeFixture,
      'path': '/post/new',
    }).forms.single;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: wallTheme(Brightness.light, null),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NativeForm(spec: spec, onSubmit: (_) async => false),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '最后输入的半句话');
    // Remove the editor before its 500 ms timer fires.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(jsonDecode(state.draft!)['content_html'], '最后输入的半句话');
    expect(jsonDecode(prefs.getString('draft')!)['content_html'], '最后输入的半句话');
  });

  test('out-of-range persisted theme settings cannot crash startup', () async {
    SharedPreferences.setMockInitialValues({'theme': 999});
    final prefs = await SharedPreferences.getInstance();
    expect(() => AppState(CountingRepository(), prefs), returnsNormally);
  });
}
