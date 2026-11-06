import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/appearance.dart';
import '../state.dart';
import 'actions.dart';
import 'design.dart';
import 'detail.dart';
import 'navigation.dart';
import 'post_card.dart';

class FeedPage extends StatefulWidget {
  final String initialQuery;
  final SiteDocument? initialDocument;
  const FeedPage({super.key, this.initialQuery = '', this.initialDocument});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final search = TextEditingController();
  final scroll = ScrollController();
  SiteDocument? document;
  List<WallPost> posts = [];
  bool loading = true, initialized = false, offline = false;
  String query = '', sort = 'latest';
  String? error;
  int? selected;
  int generation = 0;
  final Set<int> pending = {};
  Timer? debounce;
  bool? lastSignedIn;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (initialized) {
      final changed = lastSignedIn != state.signedIn;
      lastSignedIn = state.signedIn;
      if (changed && document?.signedIn != state.signedIn) load();
      return;
    }
    initialized = true;
    query = widget.initialQuery;
    search.text = query;
    lastSignedIn = state.signedIn;
    final initial = widget.initialDocument;
    if (initial != null) {
      document = initial;
      posts = initial.posts;
      sort = Uri.parse(initial.path).queryParameters['sort'] ?? 'latest';
      loading = false;
      return;
    }
    if (query.isEmpty) posts = state.cachedPosts;
    load();
  }

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    debounce?.cancel();
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    final state = AppScope.of(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final doc = await state.repository.load(
        Uri(path: '/', queryParameters: {'q': query, 'sort': sort}).toString(),
      );
      if (!mounted || request != generation) return;
      setState(() {
        document = doc;
        posts = doc.posts;
        offline = false;
        loading = false;
      });
      state.accept(doc);
      if (query.isEmpty && sort == 'latest') await state.cacheFeed(doc.posts);
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e.toString();
          loading = false;
          offline = posts.isNotEmpty;
        });
      }
    }
  }

  void filter(String value) {
    debounce?.cancel();
    query = value;
    search.text = value;
    setState(() {
      posts = [];
      selected = null;
    });
    load();
  }

  Future<void> action(WallPost post, bool favorite) async {
    if (pending.contains(post.id)) return;
    if (!await requireLogin(context)) {
      return;
    }
    if (!mounted) return;
    final state = AppScope.of(context);
    // Always acquire a fresh authenticated detail page after a login or cache restore.
    setState(() => pending.add(post.id));
    try {
      var form = favorite ? post.favoriteForm : post.likeForm;
      if (form == null) {
        final page = await state.repository.load('/?q=${post.id}');
        state.accept(page);
        final fresh = page.posts.where((p) => p.id == post.id).firstOrNull;
        form = favorite ? fresh?.favoriteForm : fresh?.likeForm;
      }
      if (form == null) throw Exception('操作暂不可用，请刷新列表后重试。');
      final values = form.values;
      // The site's next field supports returning a single numbered post. This
      // preserves complete card metadata without downloading the entire feed.
      if (values.containsKey('next')) values['next'] = '/?q=${post.id}';
      final result = await state.repository.submit(form, values);
      state.accept(result);
      if (!mounted) return;
      final updated = result.posts.where((p) => p.id == post.id).firstOrNull;
      if (updated != null) {
        setState(
          () =>
              posts = posts.map((p) => p.id == post.id ? updated : p).toList(),
        );
      } else {
        await load();
      }
      if (mounted) haptic(context);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => pending.remove(post.id));
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: wide ? 55 : 1,
            child: RefreshIndicator(
              onRefresh: load,
              child: CustomScrollView(
                controller: scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 30 : 20,
                      24,
                      wide ? 24 : 20,
                      0,
                    ),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Eyebrow('FUXING · CAMPUS WALL'),
                                  SizedBox(height: 8),
                                  Text(
                                    '校园墙',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: '入站须知',
                              onPressed: () =>
                                  openWallLink(context, '/entry-notice'),
                              icon: const Icon(CupertinoIcons.info, size: 20),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: '刷新',
                              onPressed: loading ? null : load,
                              icon: const Icon(
                                CupertinoIcons.arrow_clockwise,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _FeedHero(),
                        const SizedBox(height: 22),
                        TextField(
                          controller: search,
                          onChanged: (value) {
                            debounce?.cancel();
                            debounce = Timer(
                              const Duration(milliseconds: 450),
                              () => filter(value.trim()),
                            );
                          },
                          onSubmitted: (v) => filter(v.trim()),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '搜点什么，或输入 #帖子编号',
                            prefixIcon: const Icon(
                              CupertinoIcons.search,
                              size: 20,
                            ),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '清除搜索',
                                    onPressed: () => filter(''),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tag in [
                                '全部',
                                '表白',
                                '闲聊',
                                '求助',
                                '寻物',
                                '交友',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      tag == '全部' ? '全部话题' : '# $tag',
                                    ),
                                    selected: tag == '全部'
                                        ? query.isEmpty
                                        : query == tag,
                                    onSelected: (_) =>
                                        filter(tag == '全部' ? '' : tag),
                                    showCheckmark: false,
                                    side: BorderSide.none,
                                    labelStyle: const TextStyle(fontSize: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 14),
                          child: Row(
                            children: [
                              SegmentedButton<String>(
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: 'latest',
                                    label: Text('最新'),
                                  ),
                                  ButtonSegment(
                                    value: 'hot',
                                    label: Text('最热'),
                                  ),
                                ],
                                selected: {sort},
                                showSelectedIcon: false,
                                onSelectionChanged: (v) {
                                  setState(() => sort = v.first);
                                  load();
                                },
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  await openWallLink(context, '/lucky-post');
                                  if (mounted) load();
                                },
                                icon: const Icon(
                                  CupertinoIcons.shuffle,
                                  size: 16,
                                ),
                                label: const Text(
                                  '手气不错',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (error != null && offline)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '正在显示上次缓存的内容',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '$error\n下拉可重试；缓存内容的互动需要联网。',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        if (loading && posts.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                      ],
                    ),
                  ),
                  if (loading && posts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Busy(),
                    )
                  else if (error != null && posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title: '暂时连不上校园',
                        subtitle: error!,
                        onRetry: load,
                        icon: Icons.wifi_off_rounded,
                      ),
                    )
                  else if (posts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title: '还没有找到',
                        subtitle: '换个关键词，或试试直接搜索帖子编号。',
                        icon: CupertinoIcons.search,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 30 : 20,
                        0,
                        wide ? 24 : 20,
                        28,
                      ),
                      sliver: SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final p = posts[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: PostCard(
                              key: ValueKey(p.id),
                              post: p,
                              selected: wide && selected == p.id,
                              busy: pending.contains(p.id),
                              onTag: filter,
                              onLike: () => action(p, false),
                              onFavorite: () => action(p, true),
                              onShare: () => sharePost(context, p),
                              onOpen: () {
                                if (wide) {
                                  setState(() => selected = p.id);
                                } else {
                                  openWallLink(context, '/post/${p.id}').then((
                                    _,
                                  ) {
                                    if (mounted) load();
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  if (posts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Text(
                          '每一个声音，都值得被听见。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (wide) ...[
            VerticalDivider(
              width: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .4),
            ),
            Expanded(
              flex: 45,
              child: selected != null
                  ? PostDetail(
                      key: ValueKey(selected),
                      postId: selected!,
                      embedded: true,
                    )
                  : _ReadingAside(onTag: filter),
            ),
          ],
        ],
      );
    },
  );
}

class _FeedHero extends StatelessWidget {
  const _FeedHero();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final personalized =
        AppScope.of(context).appearance.palette != WallPalette.system;
    final foreground = personalized ? scheme.onPrimaryContainer : Colors.white;
    final muted = personalized
        ? scheme.onPrimaryContainer.withValues(alpha: .82)
        : const Color(0xFFE2E9FF);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: personalized
              ? [
                  scheme.primaryContainer,
                  Color.alphaBlend(
                    scheme.primary.withValues(alpha: .08),
                    scheme.primaryContainer,
                  ),
                ]
              : const [Color(0xFF3B60CB), Color(0xFF6A85E2)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            const Positioned(right: -50, top: -70, child: _Orbit()),
            Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: personalized
                              ? scheme.primary
                              : const Color(0xFFC9D7FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '在这里，遇见校园里的同频',
                        style: TextStyle(
                          fontSize: 10,
                          color: personalized ? muted : const Color(0xFFDDE6FF),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '说给\n校园听。',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                      height: 1.28,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '心动、日常和没说出口的话。\n匿名分享，也认真倾听。',
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.8,
                          ),
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: personalized
                              ? scheme.primary
                              : Colors.white,
                          foregroundColor: personalized
                              ? scheme.onPrimary
                              : const Color(0xFF3B60CB),
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: () => openWallLink(context, '/post/new'),
                        child: const Icon(CupertinoIcons.pencil, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orbit extends StatelessWidget {
  const _Orbit();
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.5,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final n in [200.0, 150.0, 100.0])
          Container(
            width: n,
            height: n * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .13),
                width: 1,
              ),
            ),
          ),
        const Icon(CupertinoIcons.heart, size: 34, color: Color(0xFFD9E3FF)),
      ],
    ),
  );
}

class _ReadingAside extends StatelessWidget {
  final ValueChanged<String> onTag;
  const _ReadingAside({required this.onTag});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('A LITTLE MOMENT FOR YOU'),
        const SizedBox(height: 20),
        Text('今天，也要开心。', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(
          '让心事有回音，让平凡的校园日常\n多一点点可爱。',
          style: TextStyle(
            fontSize: 13,
            height: 1.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.sparkles,
                  size: 40,
                  color: Color(0xFFC5A26C),
                ),
                const SizedBox(height: 16),
                const Text(
                  '把一点好运\n装进口袋。',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '一张小签，一句暖心话。\n看看今天的小惊喜。',
                  style: TextStyle(fontSize: 13, height: 1.8),
                ),
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: () => openWallLink(context, '/daily'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('去抽今日小签'),
                      SizedBox(width: 14),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('聊点什么'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['表白', '寻物', '闲聊', '学习', '社团']
              .map(
                (t) =>
                    ActionChip(label: Text('# $t'), onPressed: () => onTag(t)),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 14),
        const Text(
          '匿名，也请温柔一点。',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          '尊重隐私，友好讨论。发现不良内容，可以使用帖子或评论的举报入口。',
          style: TextStyle(fontSize: 12, height: 1.9),
        ),
        TextButton(
          onPressed: () => openWallLink(context, '/entry-notice'),
          child: const Text('阅读入站须知 ↗', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 40),
        const Text(
          'FUXING CAMPUS WALL\n属于我们的校园角落。',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            height: 2,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
}
