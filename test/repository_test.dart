import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_wall/data/repository.dart';
import 'package:campus_wall/data/models.dart';
import 'fixtures.dart';

class Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<ResponseBody> responses;
  Adapter(this.responses);
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

WallRepository repository(Adapter a) {
  final r = WallRepository(cookieJar: CookieJar());
  r.dio.httpClientAdapter = a;
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('untrusted actions cannot receive sessions or submitted data', () async {
    final r = repository(Adapter([]));
    for (final p in [
      'https://example.com/steal',
      'http://fxlovewall.me/login',
      'https://fxlovewall.me:444/login',
      'https://user@fxlovewall.me/login',
    ]) {
      expect(() => r.resolve(p), throwsA(isA<WallException>()));
    }
  });
  test('POST redirects become GET without leaking submitted data', () async {
    final a = Adapter([
      ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/my-posts'],
        },
      ),
      ResponseBody.fromString(
        authFeedFixture,
        200,
        headers: {
          'content-type': ['text/html'],
        },
      ),
    ]);
    final r = repository(a);
    final d = await r.submit(
      const FormSpec(action: '/login', method: 'post', label: '登录', fields: []),
      {'username': 'test', 'password': 'private'},
    );
    expect(d.signedIn, true);
    expect(a.requests.map((e) => e.method), ['POST', 'GET']);
    expect(a.requests.last.data, isNull);
    expect(a.requests.last.uri.queryParameters.containsKey('_client'), true);
  });
  test('rate limits are actionable and do not retry mutations', () async {
    final a = Adapter([ResponseBody.fromString('', 429)]);
    final r = repository(a);
    await expectLater(
      r.load('/'),
      throwsA(
        isA<WallException>().having(
          (e) => e.message,
          'message',
          contains('频繁'),
        ),
      ),
    );
    expect(a.requests.length, 1);
  });
  test('AJAX errors retain the server message', () async {
    final a = Adapter([
      ResponseBody.fromString(
        '{"ok":false,"message":"请先登录"}',
        401,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    ]);
    final r = repository(a);
    await expectLater(
      r.submit(
        const FormSpec(
          action: '/daily-lucky-item',
          method: 'post',
          label: '抽取',
          fields: [],
        ),
        {},
        ajax: true,
      ),
      throwsA(isA<WallException>().having((e) => e.message, 'message', '请先登录')),
    );
  });
}
