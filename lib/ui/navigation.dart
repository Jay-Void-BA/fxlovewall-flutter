import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/repository.dart';
import 'detail.dart';
import 'pages.dart';
import 'design.dart';

Future<void> openWallLink(BuildContext context, String path) async {
  final uri = WallRepository.origin.resolve(path);
  if (uri.scheme != 'https' ||
      uri.host != WallRepository.origin.host ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty) {
    if (['https', 'http'].contains(uri.scheme)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }
  final match = RegExp(r'^/post/(\d+)$').firstMatch(uri.path);
  haptic(context);
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => match != null
          ? PostDetail(postId: int.parse(match.group(1)!))
          : SitePage(path: '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}'),
    ),
  );
}
