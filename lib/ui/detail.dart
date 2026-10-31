import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state.dart';
import 'actions.dart';
import 'design.dart';
import 'forms.dart';
import 'navigation.dart';

class PostDetail extends StatefulWidget {
  final int postId;
  final bool embedded;
  final SiteDocument? initialDocument;
  const PostDetail({
    super.key,
    required this.postId,
    this.embedded = false,
    this.initialDocument,
  });
  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  SiteDocument? doc;
  String? error;
  bool initialized = false, loading = true, busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    if (widget.initialDocument != null) {
      doc = widget.initialDocument;
      loading = false;
    } else {
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final state = AppScope.of(context);
      final result = await state.repository.load('/post/${widget.postId}');
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
    final result = await state.repository.submit(form, values);
    if (!mounted) return false;
    state.accept(result);
    if (!result.signedIn) {
      await openWallLink(context, '/login');
      if (mounted) await load();
      return false;
    }
    setState(() => doc = result);
    if (result.messages.isNotEmpty) toast(context, result.messages.join('\n'));
    return result.messages.every(
      (s) => !RegExp('失败|不能|禁止|错误|频繁|不足|至少|最多').hasMatch(s),
    );
  }

  Future<void> like() async {
    if (busy) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      if (doc?.posts.firstOrNull?.likeForm == null) await load();
      if (!mounted) return;
      final form = doc?.posts.firstOrNull?.likeForm;
      if (form != null) {
        await submit(form, form.values);
        if (mounted) haptic(context);
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> moreAction(String action) async {
    if (action == 'report') {
      final report = doc?.posts.firstOrNull?.reportPath;
      if (report != null) {
        await openWallLink(context, report);
      } else if (await requireLogin(context) && mounted) {
        await load();
        if (mounted) {
          await openWallLink(context, '/post/${widget.postId}/report');
        }
      }
      return;
    }
    if (action == 'favorite' && !await requireLogin(context)) return;
    if (!mounted) return;
    try {
      final state = AppScope.of(context);
      final feed = await state.repository.load('/?q=${widget.postId}');
      state.accept(feed);
      final post = feed.posts.where((p) => p.id == widget.postId).firstOrNull;
      if (post == null || !mounted) return;
      if (action == 'favorite') {
        final form = post.favoriteForm;
        if (form == null) return;
        final result = await state.repository.submit(form, form.values);
        state.accept(result);
        if (mounted) toast(context, post.favorited ? '已取消收藏' : '已收藏');
      } else {
        await sharePost(context, post, copy: action == 'copy');
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = doc?.posts.firstOrNull;
    final commentForm = doc?.forms
        .where((f) => f.action.endsWith('/comment'))
        .firstOrNull;
    final theme = Theme.of(context);
    final content = loading && doc == null
        ? const Busy()
        : error != null && doc == null
        ? EmptyState(title: '帖子暂时无法读取', subtitle: error!, onRetry: load)
        : post == null
        ? EmptyState(
            title: '这条帖子暂不可见',
            subtitle: '它可能正在审核，或已被隐藏。',
            onRetry: load,
          )
        : RefreshIndicator(
            onRefresh: load,
            child: SelectionArea(
              child: ListView(
                padding: EdgeInsets.all(widget.embedded ? 28 : 22),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (widget.embedded)
                    Row(
                      children: [
                        const Eyebrow('THE CONVERSATION'),
                        const Spacer(),
                        IconButton(
                          tooltip: '刷新帖子',
                          onPressed: load,
                          icon: const Icon(Icons.refresh, size: 20),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: .5,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          CupertinoIcons.bubble_left_bubble_right,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '匿名 #${post.id}',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              post.time,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '帖子操作',
                        onSelected: moreAction,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'favorite',
                            child: Text('收藏 / 取消收藏'),
                          ),
                          PopupMenuItem(value: 'share', child: Text('分享帖子')),
                          PopupMenuItem(value: 'copy', child: Text('复制分享链接')),
                          PopupMenuItem(value: 'report', child: Text('举报帖子')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (post.controversial)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '该帖可能存在争议，请理性看待。',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  if (post.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Wrap(
                        spacing: 8,
                        children: post.tags
                            .map(
                              (t) => ActionChip(
                                label: Text('# $t'),
                                onPressed: () => openWallLink(
                                  context,
                                  '/?q=${Uri.encodeComponent(t)}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  WallHtml(
                    post.contentHtml,
                    large: true,
                    onLink: (url) => openWallLink(context, url),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: busy ? null : like,
                        icon: Icon(
                          post.liked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 19,
                        ),
                        label: Text('${post.likes} 人赞过'),
                      ),
                      const Spacer(),
                      Text(
                        '${doc!.comments.length} 条评论',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  SectionTitle(
                    '听听大家怎么说',
                    trailing: Text(
                      '${doc!.comments.length}',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                  if (commentForm != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: NativeForm(
                          key: ValueKey('comment-${doc.hashCode}'),
                          spec: commentForm,
                          onSubmit: (values) => submit(commentForm, values),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: ListTile(
                        leading: const Icon(CupertinoIcons.chat_bubble),
                        title: const Text(
                          '加入这场对话',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          '登录后即可匿名评论',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await openWallLink(context, '/login');
                          if (mounted) load();
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  if (doc!.comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        '还没有评论，来留下第一句回应吧。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  for (final c in doc!.comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                c.time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (c.reportPath != null)
                                IconButton(
                                  tooltip: '举报评论',
                                  onPressed: () =>
                                      openWallLink(context, c.reportPath!),
                                  icon: const Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          WallHtml(
                            c.contentHtml,
                            onLink: (url) => openWallLink(context, url),
                          ),
                          const SizedBox(height: 18),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: .4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (loading) const LinearProgressIndicator(minHeight: 2),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '帖子 #${widget.postId}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: content,
        ),
      ),
    );
  }
}
