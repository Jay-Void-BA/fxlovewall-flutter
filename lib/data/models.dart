import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

String cleanText(Element? element) {
  if (element == null) return '';
  final copy = element.clone(true);
  for (final br in copy.querySelectorAll('br')) {
    br.replaceWith(Text('\n'));
  }
  return copy.text.trim();
}

class SiteLink {
  final String label, href;
  const SiteLink(this.label, this.href);
}

class FieldSpec {
  final String name, type, label, value, placeholder;
  final bool required, checked;
  final int? maxLength, minLength;
  final List<SiteLink> options;
  const FieldSpec({
    required this.name,
    required this.type,
    this.label = '',
    this.value = '',
    this.placeholder = '',
    this.required = false,
    this.checked = false,
    this.maxLength,
    this.minLength,
    this.options = const [],
  });
}

class FormSpec {
  final String action, method, label;
  final List<FieldSpec> fields;
  const FormSpec({
    required this.action,
    required this.method,
    required this.label,
    required this.fields,
  });
  Map<String, String> get values => {
    for (final f in fields)
      if (f.type != 'checkbox' || f.checked) f.name: f.value,
  };

  static FormSpec fromElement(Element form, String path) {
    final fields = <FieldSpec>[];
    for (final input in form.querySelectorAll('input, textarea, select')) {
      final name = input.attributes['name'];
      if (name == null || input.attributes.containsKey('disabled')) continue;
      var type = input.localName == 'textarea'
          ? 'textarea'
          : input.localName == 'select'
          ? 'select'
          : input.attributes['type'] ?? 'text';
      if (name == 'content_html') type = 'editor';
      if (type == 'submit' || type == 'button') continue;
      final id = input.id;
      final label = id.isNotEmpty
          ? form
                .querySelectorAll('label')
                .where((e) => e.attributes['for'] == id)
                .firstOrNull
          : null;
      Element? prev = input.previousElementSibling;
      if (prev?.localName != 'label') prev = null;
      final options = input.querySelectorAll('option');
      fields.add(
        FieldSpec(
          name: name,
          type: type,
          label: cleanText(label ?? prev).isNotEmpty
              ? cleanText(label ?? prev)
              : switch (name) {
                  'username' => '账号名',
                  'password' => '密码',
                  'password2' => '确认密码',
                  'content_html' => '想说的话',
                  'content' => '评论内容',
                  'tags' => '标签',
                  'reason' => '举报原因',
                  'allow_share' => '允许分享这篇帖子',
                  _ => name,
                },
          value: type == 'textarea'
              ? input.text
              : type == 'editor'
              ? (input.attributes['value'] ?? '')
              : input.attributes['value'] ??
                    (type == 'checkbox'
                        ? 'on'
                        : type == 'select'
                        ? (options
                                          .where(
                                            (e) => e.attributes.containsKey(
                                              'selected',
                                            ),
                                          )
                                          .firstOrNull ??
                                      options.firstOrNull)
                                  ?.attributes['value'] ??
                              ''
                        : ''),
          placeholder: input.attributes['placeholder'] ?? '',
          required: input.attributes.containsKey('required'),
          checked: input.attributes.containsKey('checked'),
          maxLength: int.tryParse(
            input.attributes['maxlength'] ?? (type == 'editor' ? '1000' : ''),
          ),
          minLength: int.tryParse(input.attributes['minlength'] ?? ''),
          options: options
              .map((e) => SiteLink(e.text, e.attributes['value'] ?? e.text))
              .toList(),
        ),
      );
    }
    // The website's contenteditable editor stores its value in a hidden field.
    final editor = form.querySelector('[contenteditable="true"]');
    if (editor != null) {
      final i = fields.indexWhere((f) => f.type == 'editor');
      if (i >= 0) {
        fields[i] = FieldSpec(
          name: fields[i].name,
          type: 'editor',
          label: '想说的话',
          value: editor.innerHtml,
          required: true,
          maxLength: 1000,
        );
      }
    }
    final submit = form.querySelector(
      'button[type="submit"], button:not([type]), input[type="submit"]',
    );
    return FormSpec(
      action: form.attributes['action']?.isNotEmpty == true
          ? form.attributes['action']!
          : path,
      method: (form.attributes['method'] ?? 'get').toLowerCase(),
      label: cleanText(submit).isNotEmpty
          ? cleanText(submit)
          : submit?.attributes['value'] ?? '提交',
      fields: fields,
    );
  }
}

class WallPost {
  final int id, likes, comments;
  final String contentHtml, text, time;
  final List<String> tags;
  final bool controversial, liked, favorited, shareable;
  final FormSpec? likeForm, favoriteForm, shareForm;
  final String? reportPath;
  const WallPost({
    required this.id,
    required this.contentHtml,
    required this.text,
    required this.time,
    this.likes = 0,
    this.comments = 0,
    this.tags = const [],
    this.controversial = false,
    this.liked = false,
    this.favorited = false,
    this.shareable = false,
    this.likeForm,
    this.favoriteForm,
    this.shareForm,
    this.reportPath,
  });
  factory WallPost.fromElement(Element e, String path) {
    final title = e.querySelector('.post-meta strong')?.text ?? '';
    final id =
        int.tryParse(RegExp(r'#(\d+)').firstMatch(title)?.group(1) ?? '') ?? 0;
    final forms = e
        .querySelectorAll('form')
        .map((f) => FormSpec.fromElement(f, path))
        .toList();
    final like = forms.where((f) => f.action.endsWith('/like')).firstOrNull;
    final favorite = forms
        .where((f) => f.action.endsWith('/favorite'))
        .firstOrNull;
    final share = forms.where((f) => f.action.endsWith('/share')).firstOrNull;
    final content = e.querySelector('.post-content');
    final commentLink = e
        .querySelectorAll('a')
        .where((a) => a.text.contains('评论'))
        .firstOrNull;
    final likesText =
        like?.label ?? e.querySelector('.left-actions')?.text ?? '';
    return WallPost(
      id: id,
      contentHtml: content?.innerHtml ?? '',
      text: cleanText(content),
      time: e.querySelector('.post-meta > span')?.text.trim() ?? '',
      likes:
          int.tryParse(RegExp(r'\d+').firstMatch(likesText)?.group(0) ?? '') ??
          0,
      comments:
          int.tryParse(
            RegExp(r'\d+').firstMatch(commentLink?.text ?? '')?.group(0) ?? '',
          ) ??
          0,
      tags: e
          .querySelectorAll('.tag')
          .map((x) => x.text.trim().replaceFirst('#', ''))
          .toList(),
      controversial: e.querySelector('.controversy-notice') != null,
      liked:
          e.querySelector('.like-button.liked, .like-button.active') != null ||
          likesText.contains('取消'),
      favorited:
          favorite?.label.contains('取消') == true ||
          favorite?.label.contains('已收藏') == true,
      shareable: share != null,
      likeForm: like,
      favoriteForm: favorite,
      shareForm: share,
      reportPath: e
          .querySelectorAll('a')
          .where((a) => a.attributes['href']?.endsWith('/report') == true)
          .firstOrNull
          ?.attributes['href'],
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'html': contentHtml,
    'text': text,
    'time': time,
    'likes': likes,
    'comments': comments,
    'tags': tags,
    'controversial': controversial,
    'shareable': shareable,
  };
  factory WallPost.fromJson(Map<String, dynamic> j) => WallPost(
    id: j['id'],
    contentHtml: j['html'],
    text: j['text'],
    time: j['time'],
    likes: j['likes'],
    comments: j['comments'],
    tags: List<String>.from(j['tags']),
    controversial: j['controversial'] ?? false,
    shareable: j['shareable'] ?? false,
  );
}

class WallComment {
  final String label, time, contentHtml;
  final String? reportPath;
  const WallComment(this.label, this.time, this.contentHtml, this.reportPath);
}

class ContentBlock {
  final String html;
  final FormSpec? form;
  const ContentBlock.content(this.html) : form = null;
  const ContentBlock.form(this.form) : html = '';
}

class FortuneCardData {
  final String label, contentHtml;
  final FormSpec? form;
  final bool love;
  const FortuneCardData(this.label, this.contentHtml, this.form, this.love);
}

class SiteDocument {
  final String path, title;
  final bool signedIn;
  final List<WallPost> posts;
  final List<WallComment> comments;
  final List<FormSpec> forms;
  final List<ContentBlock> blocks;
  final List<SiteLink> navigation;
  final List<String> messages;
  final FormSpec? logoutForm;
  final List<FortuneCardData> fortunes;
  final String luckyResult;
  const SiteDocument({
    required this.path,
    required this.title,
    required this.signedIn,
    required this.posts,
    required this.comments,
    required this.forms,
    required this.blocks,
    required this.navigation,
    required this.messages,
    this.logoutForm,
    this.fortunes = const [],
    this.luckyResult = '',
  });
}

// A top-level function runs the large server-rendered feed parser off the UI isolate.
SiteDocument parseDocument(Map<String, String> args) {
  final d = html.parse(args['html']!);
  final path = args['path']!;
  final main = d.querySelector('main') ?? d.body!;
  final allForms = main
      .querySelectorAll('form')
      .where((f) {
        for (
          Element? parent = f.parent;
          parent != null;
          parent = parent.parent
        ) {
          if (parent.localName == 'article' &&
              parent.classes.contains('post')) {
            return false;
          }
        }
        return true;
      })
      .map((f) => FormSpec.fromElement(f, path))
      .toList();
  final logout = d.querySelector('form[action="/logout"]');
  final posts = main
      .querySelectorAll('article.post')
      .map((e) => WallPost.fromElement(e, path))
      .toList();
  final comments = main
      .querySelectorAll('article.comment')
      .map(
        (e) => WallComment(
          cleanText(e.querySelector('.comment-meta strong')),
          cleanText(e.querySelector('.comment-meta span')),
          e.querySelector('.comment-content')?.innerHtml ?? '',
          e.querySelector('a[href*="/report"]')?.attributes['href'],
        ),
      )
      .toList();
  // Split generic pages into HTML and native forms in document order. JavaScript
  // is never executed; the actual server form names/actions remain authoritative.
  final blocks = <ContentBlock>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isNotEmpty) {
      blocks.add(ContentBlock.content(buffer.toString()));
      buffer.clear();
    }
  }

  void visit(Element e) {
    if (['script', 'style'].contains(e.localName) ||
        e.classes.contains('flash-container')) {
      return;
    }
    if (e.localName == 'form') {
      flush();
      blocks.add(ContentBlock.form(FormSpec.fromElement(e, path)));
      return;
    }
    if (e.querySelector('form') == null) {
      buffer.write(e.outerHtml);
      return;
    }
    for (final node in e.nodes) {
      if (node is Element) {
        visit(node);
      } else if (node is Text && node.text.trim().isNotEmpty) {
        buffer.write(node.text);
      }
    }
  }

  if (Uri.parse(path).path != '/') {
    for (final child in main.children) {
      visit(child);
    }
  }
  flush();
  return SiteDocument(
    path: path,
    title: cleanText(d.querySelector('title')),
    signedIn: logout != null,
    posts: posts,
    comments: comments,
    forms: allForms,
    blocks: blocks,
    luckyResult: cleanText(main.querySelector('#daily-lucky-item-result')),
    fortunes: main.querySelectorAll('.fortune-card').map((e) {
      final copy = e.clone(true);
      for (final item in copy.querySelectorAll(
        'form, .fortune-icon, .fortune-label',
      )) {
        item.remove();
      }
      final form = e.querySelector('form');
      return FortuneCardData(
        cleanText(e.querySelector('.fortune-label')),
        copy.innerHtml,
        form == null ? null : FormSpec.fromElement(form, path),
        e.classes.contains('love-card'),
      );
    }).toList(),
    logoutForm: logout == null ? null : FormSpec.fromElement(logout, path),
    navigation: d
        .querySelectorAll('header nav a')
        .map((e) => SiteLink(e.text.trim(), e.attributes['href'] ?? '/'))
        .toList(),
    messages: d
        .querySelectorAll(
          '.flash-container > div, .flash, .alert, .error-message',
        )
        .map(cleanText)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(),
  );
}
