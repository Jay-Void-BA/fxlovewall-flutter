// Opt-in live verification. Credentials are read from a local, unbundled file.
// Publication requires the separate FXWALL_TEST_PUBLISH_COMMENT=true opt-in.
// The published text explicitly identifies ChatGPT and is idempotently checked.
import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_wall/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live public and authenticated website forms',
    () async {
      HttpOverrides.global = null;
      final credentialsPath = Platform.environment['FXWALL_TEST_CREDENTIALS'];
      expect(credentialsPath, isNotNull);
      final credentials =
          jsonDecode(File(credentialsPath!).readAsStringSync())
              as Map<String, dynamic>;
      final r = WallRepository(cookieJar: CookieJar());
      final trust = SecurityContext(withTrustedRoots: true);
      final caPath = Platform.environment['FXWALL_TEST_CA'];
      if (caPath != null) trust.setTrustedCertificates(caPath);
      r.dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            HttpClient(context: trust)
              ..findProxy = HttpClient.findProxyFromEnvironment,
      );
      int responseBytes = 0;
      r.dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            responseBytes = utf8.encode(response.data?.toString() ?? '').length;
            handler.next(response);
          },
        ),
      );
      final home = await r.load('/');
      expect(home.posts, isNotEmpty);
      final first = home.posts.first;
      final detail = await r.load('/post/${first.id}');
      expect(detail.posts.single.id, first.id);
      final login = await r.load('/login');
      final f = login.forms.single;
      final logged = await r.submit(f, {
        ...f.values,
        'username': credentials['username'],
        'password': credentials['password'],
      });
      expect(logged.signedIn, true);
      final fullHomeBytes = responseBytes;
      final composer = await r.load('/post/new');
      expect(composer.forms.single.fields.any((f) => f.type == 'editor'), true);
      final mine = await r.load('/my-posts');
      expect(mine.blocks.map((b) => b.html).join(), contains('ChatGPT'));
      final report = await r.load('/post/${first.id}/report');
      expect(report.forms.single.fields.any((f) => f.name == 'reason'), true);
      // Toggle a bookmark and restore its original value, checking actual server state.
      var search = await r.load('/?q=${first.id}');
      final original = search.posts.firstWhere((p) => p.id == first.id);
      final fav = original.favoriteForm!;
      final bookmarked = await r.submit(fav, {
        ...fav.values,
        'next': '/?q=${first.id}',
      });
      final singlePostBytes = responseBytes;
      expect(bookmarked.posts.length, 1);
      expect(bookmarked.posts.single.id, first.id);
      search = await r.load('/?q=${first.id}');
      final toggled = search.posts.firstWhere((p) => p.id == first.id);
      expect(toggled.favorited, !original.favorited);
      final undo = toggled.favoriteForm!;
      await r.submit(undo, {...undo.values, 'next': '/?q=${first.id}'});
      search = await r.load('/?q=${first.id}');
      expect(
        search.posts.firstWhere((p) => p.id == first.id).favorited,
        original.favorited,
      );
      if (Platform.environment['FXWALL_TEST_PUBLISH_COMMENT'] == 'true') {
        const text =
            '我是 ChatGPT，受使用者委托开发 Flutter 安卓 / iOS 校园墙客户端，正在验证评论功能。平板适配也在进行中。祝同学们交流愉快！（客户端兼容性测试）';
        final discussion = await r.load('/post/225');
        if (!discussion.comments.any(
          (c) => c.contentHtml.contains('我是 ChatGPT，受使用者委托开发 Flutter'),
        )) {
          final comment = discussion.forms.firstWhere(
            (f) => f.action.endsWith('/comment'),
          );
          final result = await r.submit(comment, {
            ...comment.values,
            'content': text,
          });
          expect(
            result.comments.any((c) => c.contentHtml.contains('我是 ChatGPT')),
            true,
          );
        }
      }
      final metricsPath = Platform.environment['FXWALL_TEST_METRICS'];
      if (metricsPath != null) {
        File(metricsPath).writeAsStringSync(
          jsonEncode({
            'full_authenticated_home_bytes': fullHomeBytes,
            'single_post_bookmark_response_bytes': singlePostBytes,
            'reduction_percent': (1 - singlePostBytes / fullHomeBytes) * 100,
          }),
        );
      }
      // A warm sentence is an existing entertainment action without public content.
      final daily = await r.load('/daily');
      final warm = daily.forms.firstWhere((f) => f.action == '/daily/warm');
      final sentence = await r.submit(warm, warm.values);
      expect(sentence.title, '今日小签');
      final logout = logged.logoutForm!;
      final out = await r.submit(logout, logout.values);
      expect(out.signedIn, false);
    },
    skip: !const bool.fromEnvironment('RUN_LIVE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
