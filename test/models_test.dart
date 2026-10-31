import 'package:flutter_test/flutter_test.dart';
import 'package:campus_wall/data/models.dart';
import 'package:campus_wall/ui/editor.dart';
import 'package:flutter/material.dart';
import 'fixtures.dart';

void main() {
  test(
    'feed retains line breaks, colors, tags, share permissions and counts',
    () {
      final d = parseDocument({'html': feedFixture, 'path': '/'});
      final p = d.posts.single;
      expect(d.signedIn, false);
      expect(p.id, 42);
      expect(p.likes, 3);
      expect(p.comments, 1);
      expect(p.text, '秋天的校园真好看。\n一起去散步吧！');
      expect(p.tags, ['闲聊']);
      expect(p.contentHtml, contains('post-color-blue'));
      expect(p.shareable, true);
      expect(p.shareForm!.values['csrf_token'], 'fixture-token');
    },
  );
  test('authenticated state and actual action forms are extracted', () {
    final d = parseDocument({'html': authFeedFixture, 'path': '/'});
    final p = d.posts.single;
    expect(d.signedIn, true);
    expect(d.logoutForm!.action, '/logout');
    expect(p.liked, true);
    expect(p.favorited, true);
    expect(p.likeForm!.values['next'], '/');
    expect(p.reportPath, '/post/42/report');
  });
  test('public cached JSON contains no tokens or mutation forms', () {
    final post = parseDocument({
      'html': authFeedFixture,
      'path': '/',
    }).posts.single;
    final json = post.toJson();
    expect(json.toString(), isNot(contains('fixture-token')));
    final copy = WallPost.fromJson(json);
    expect(copy.id, 42);
    expect(copy.likeForm, isNull);
    expect(copy.favorited, false);
  });
  test('comment IDs, dates and report routes survive parsing', () {
    final d = parseDocument({'html': detailFixture, 'path': '/post/42'});
    expect(d.comments.single.label, '匿名评论 #7');
    expect(d.comments.single.reportPath, '/comment/7/report');
  });
  test('composer recognizes hidden HTML field and checkbox semantics', () {
    final d = parseDocument({'html': composeFixture, 'path': '/post/new'});
    final f = d.forms.single;
    expect(f.action, '/post/new');
    expect(f.fields.where((f) => f.type == 'editor').single.required, true);
    expect(f.fields.where((f) => f.name == 'allow_share').single.value, 'on');
    expect(d.blocks.where((b) => b.form != null).length, 1);
  });
  test('selection formatting escapes HTML and responds to text edits', () {
    final c = WallEditorController('你好 &lt;校园&gt;');
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    c.format(color: 'blue', italic: true);
    expect(
      c.toHtml(),
      '<span class="post-color-blue" style="color:#5f78a8"><em>你好</em></span> &lt;校园&gt;',
    );
    c.value = TextEditingValue(
      text: '嘿${c.text}',
      selection: const TextSelection.collapsed(offset: 1),
    );
    expect(c.toHtml(), contains('<em>你好</em>'));
    c.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    c.format(clear: true);
    expect(c.toHtml(), isNot(contains('post-color-blue')));
    c.dispose();
  });
}
