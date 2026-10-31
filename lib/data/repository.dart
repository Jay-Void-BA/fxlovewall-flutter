import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class SecureCookieStorage implements Storage {
  final FlutterSecureStorage secure;
  const SecureCookieStorage(this.secure);
  String key(String key) => 'fxwall.cookie.$key';
  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}
  @override
  Future<String?> read(String key) => secure.read(key: this.key(key));
  @override
  Future<void> write(String key, String value) =>
      secure.write(key: this.key(key), value: value);
  @override
  Future<void> delete(String key) => secure.delete(key: this.key(key));
  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }
}

class WallException implements Exception {
  final String message;
  const WallException(this.message);
  @override
  String toString() => message;
}

class WallRepository {
  static final origin = Uri.parse('https://fxlovewall.me');
  final Dio dio;
  final CookieJar cookies;
  WallRepository({Dio? client, CookieJar? cookieJar})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: origin.toString(),
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 20),
              responseType: ResponseType.plain,
              followRedirects: false,
              validateStatus: (s) => s != null && s < 600,
              headers: {
                'User-Agent': 'FXWall-Flutter/1.0 (native client)',
                'Accept': 'text/html,application/json',
              },
            ),
          ),
      cookies =
          cookieJar ??
          PersistCookieJar(
            storage: const SecureCookieStorage(FlutterSecureStorage()),
          ) {
    dio.interceptors.add(CookieManager(cookies));
  }

  Uri resolve(String path) {
    final uri = origin.resolve(path);
    if (uri.scheme != 'https' ||
        uri.host != origin.host ||
        uri.port != origin.port ||
        uri.userInfo.isNotEmpty) {
      throw const WallException('该链接将离开校园墙，请在浏览器中打开。');
    }
    return uri;
  }

  Future<SiteDocument> load(String path) => _request(resolve(path), 'GET');

  Future<SiteDocument> submit(
    FormSpec form,
    Map<String, String> values, {
    bool ajax = false,
  }) async {
    var uri = resolve(form.action);
    if (form.method == 'get') {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...values});
      return _request(uri, 'GET');
    }
    return _request(uri, 'POST', values: values, ajax: ajax);
  }

  Future<SiteDocument> _request(
    Uri uri,
    String method, {
    Map<String, String>? values,
    bool ajax = false,
  }) async {
    try {
      for (var redirects = 0; redirects < 8; redirects++) {
        // Unique GETs prevent a shared upstream cache from replaying another
        // session's CSRF form. Never cache authenticated HTML on disk.
        final target = method == 'GET'
            ? uri.replace(
                queryParameters: {
                  ...uri.queryParameters,
                  '_client': DateTime.now().microsecondsSinceEpoch.toString(),
                },
              )
            : uri;
        final response = await dio.requestUri<String>(
          target,
          data: values == null ? null : FormData.fromMap(values),
          options: Options(
            method: method,
            headers: {
              'Cache-Control': 'no-cache',
              'Referer': uri.toString(),
              'Origin': origin.toString(),
              if (ajax) 'X-Requested-With': 'XMLHttpRequest',
            },
          ),
        );
        final status = response.statusCode ?? 0;
        if ([301, 302, 303, 307, 308].contains(status)) {
          final location = response.headers.value('location');
          if (location == null) throw const WallException('服务器返回了无效跳转。');
          uri = resolve(uri.resolve(location).toString());
          if (status != 307 && status != 308) {
            method = 'GET';
            values = null;
          }
          continue;
        }
        final body = response.data ?? '';
        if (response.headers
                .value('content-type')
                ?.contains('application/json') ==
            true) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          if (status >= 400 || data['ok'] == false) {
            throw WallException(data['message']?.toString() ?? '操作失败，请稍后重试。');
          }
          return SiteDocument(
            path: uri.path,
            title: '',
            signedIn: false,
            posts: [],
            comments: [],
            forms: [],
            blocks: [],
            navigation: [],
            messages: [data['message']?.toString() ?? '操作成功'],
          );
        }
        if (status == 429) throw const WallException('操作太频繁，请稍等一会儿再试。');
        if (status == 400) throw const WallException('页面已过期，请刷新页面后再试。');
        if (status == 401 || status == 403) {
          throw const WallException('请重新登录，或检查账号权限。');
        }
        if (status == 404) throw const WallException('这条内容不存在或暂时不可见。');
        if (status >= 500) throw const WallException('校园墙暂时没有响应，请稍后重试。');
        final params = Map<String, String>.from(uri.queryParameters)
          ..remove('_client');
        final clean = uri.replace(
          queryParameters: params.isEmpty ? null : params,
        );
        return await compute(parseDocument, {
          'html': body,
          'path': '${clean.path}${clean.hasQuery ? '?${clean.query}' : ''}',
        });
      }
      throw const WallException('页面跳转次数过多，请重新登录。');
    } on DioException catch (e) {
      throw WallException(
        e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout
            ? '连接超时，请检查网络后重试。'
            : '暂时无法连接校园墙，请检查网络后重试。',
      );
    }
  }

  Future<void> clearSession() => cookies.deleteAll();
}
