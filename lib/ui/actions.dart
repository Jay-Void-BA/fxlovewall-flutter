import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models.dart';
import '../state.dart';
import 'design.dart';
import 'navigation.dart';

Future<void> sharePost(
  BuildContext context,
  WallPost post, {
  bool copy = false,
}) async {
  if (!post.shareable) {
    toast(context, '作者未开启分享。');
    return;
  }
  final state = AppScope.of(context);
  final text = '来自表白墙的最新分享：https://fxlovewall.me/post/${post.id}';
  try {
    bool completed;
    if (copy) {
      await Clipboard.setData(ClipboardData(text: text));
      completed = true;
      if (context.mounted) toast(context, '帖子链接已复制');
    } else {
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
      completed = result.status == ShareResultStatus.success;
    }
    if (completed && post.shareForm != null) {
      // Sharing is already complete; a telemetry failure should not report a failed share.
      try {
        await state.repository.submit(
          post.shareForm!,
          post.shareForm!.values,
          ajax: true,
        );
      } catch (_) {}
    }
  } catch (_) {
    if (context.mounted) toast(context, '暂时无法打开分享，请使用复制链接。');
  }
}

Future<bool> requireLogin(BuildContext context) async {
  final state = AppScope.of(context);
  if (state.signedIn) return true;
  await openWallLink(context, '/login');
  return state.signedIn;
}
