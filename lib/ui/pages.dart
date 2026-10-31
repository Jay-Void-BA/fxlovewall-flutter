import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../state.dart';
import 'design.dart';
import 'daily.dart';
import 'detail.dart';
import 'feed.dart';
import 'forms.dart';
import 'navigation.dart';

class SitePage extends StatefulWidget {
  final String path;
  final bool embedded;
  const SitePage({super.key, required this.path, this.embedded = false});
  @override
  State<SitePage> createState() => _SitePageState();
}

class _SitePageState extends State<SitePage> {
  SiteDocument? doc;
  String? error;
  bool loading = true, initialized = false;
  String get path => doc?.path ?? widget.path;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final state = AppScope.of(context);
      final result = await state.repository.load(path);
      if (!mounted) return;
      state.accept(result);
      setState(() {
        doc = result;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<bool> submit(FormSpec form, Map<String, String> values) async {
    final state = AppScope.of(context);
    final result = await state.repository.submit(
      form,
      values,
      ajax: form.action == '/daily-lucky-item',
    );
    if (!mounted) return false;
    state.accept(result);
    if (form.action.contains('/login') && result.signedIn) {
      TextInput.finishAutofillContext();
      if (widget.path.startsWith('/login') ||
          widget.path.startsWith('/register')) {
        Navigator.pop(context, true);
      } else {
        final resumed = await state.repository.load(widget.path);
        if (mounted) {
          state.accept(resumed);
          setState(() => doc = resumed);
        }
      }
      return true;
    }
    if (result.title.isEmpty) {
      toast(context, result.messages.join('\n'));
      await load();
      return true;
    }
    setState(() => doc = result);
    if (result.messages.isNotEmpty) toast(context, result.messages.join('\n'));
    if (result.path != form.action) return true;
    return result.messages.any((s) => s.contains('成功'));
  }

  @override
  Widget build(BuildContext context) {
    final current = doc;
    if (current != null &&
        RegExp(r'^/post/\d+$').hasMatch(Uri.parse(current.path).path)) {
      return PostDetail(
        postId: current.posts.firstOrNull?.id ?? 0,
        initialDocument: current,
        embedded: widget.embedded,
      );
    }
    if (current != null && Uri.parse(current.path).path == '/') {
      final feed = FeedPage(
        initialQuery: Uri.parse(current.path).queryParameters['q'] ?? '',
        initialDocument: current,
      );
      return widget.embedded
          ? feed
          : Scaffold(
              appBar: AppBar(title: const Text('校园墙')),
              body: feed,
            );
    }
    final auth = path.startsWith('/login') || path.startsWith('/register');
    final daily = path.startsWith('/daily');
    final content = loading && current == null
        ? const Busy()
        : error != null && current == null
        ? EmptyState(title: '暂时无法读取', subtitle: error!, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(auth ? 28 : 24),
              children: [
                if (auth) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        CupertinoIcons.bubble_left_bubble_right_fill,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Eyebrow('YOUR LITTLE CAMPUS CORNER')),
                  const SizedBox(height: 12),
                ],
                if (daily && current != null)
                  DailyContent(
                    document: current,
                    onSubmit: submit,
                    onRefresh: load,
                  ),
                for (final message in current?.messages ?? <String>[])
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(message),
                  ),
                for (final (index, block)
                    in (daily
                            ? <ContentBlock>[]
                            : current?.blocks ?? <ContentBlock>[])
                        .indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: block.form != null
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: NativeForm(
                                key: ValueKey('${current.hashCode}-$index'),
                                spec: block.form!,
                                onSubmit: (values) =>
                                    submit(block.form!, values),
                              ),
                            ),
                          )
                        : daily && index > 0
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: index.isEven
                                  ? Theme.of(context)
                                        .colorScheme
                                        .tertiaryContainer
                                        .withValues(alpha: .4)
                                  : Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: WallHtml(
                              block.html,
                              onLink: (url) => openWallLink(context, url),
                            ),
                          )
                        : SelectionArea(
                            child: WallHtml(
                              block.html,
                              onLink: (url) => openWallLink(context, url),
                            ),
                          ),
                  ),
                if (auth)
                  TextButton(
                    onPressed: () async {
                      final next = path.startsWith('/login')
                          ? '/register'
                          : '/login';
                      setState(() {
                        doc = null;
                      });
                      final state = AppScope.of(context);
                      try {
                        final result = await state.repository.load(next);
                        if (mounted) setState(() => doc = result);
                      } catch (e) {
                        if (context.mounted) toast(context, e.toString());
                      }
                    },
                    child: Text(
                      path.startsWith('/login') ? '还没有账号？创建匿名账号' : '已有账号？去登录',
                    ),
                  ),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          );
    final constrained = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: auth ? 520 : 800),
        child: content,
      ),
    );
    if (widget.embedded) return constrained;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          current?.title ?? '校园墙',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: loading ? null : load,
            icon: const Icon(CupertinoIcons.arrow_clockwise, size: 20),
          ),
        ],
      ),
      body: constrained,
    );
  }
}
