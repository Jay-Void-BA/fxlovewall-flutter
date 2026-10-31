import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../state.dart';
import 'design.dart';
import 'feed.dart';
import 'navigation.dart';
import 'pages.dart';

const appleDestinations = [
  (
    label: '校园墙',
    icon: CupertinoIcons.square_grid_2x2,
    selected: CupertinoIcons.square_grid_2x2_fill,
  ),
  (
    label: '发现',
    icon: CupertinoIcons.compass,
    selected: CupertinoIcons.compass_fill,
  ),
  (
    label: '今日小签',
    icon: CupertinoIcons.sparkles,
    selected: CupertinoIcons.sparkles,
  ),
  (
    label: '我的',
    icon: CupertinoIcons.person_crop_circle,
    selected: CupertinoIcons.person_crop_circle_fill,
  ),
];
const materialDestinations = [
  (
    label: '校园墙',
    icon: Icons.grid_view_outlined,
    selected: Icons.grid_view_rounded,
  ),
  (label: '发现', icon: Icons.explore_outlined, selected: Icons.explore_rounded),
  (
    label: '今日小签',
    icon: Icons.auto_awesome_outlined,
    selected: Icons.auto_awesome_rounded,
  ),
  (
    label: '我的',
    icon: Icons.account_circle_outlined,
    selected: Icons.account_circle_rounded,
  ),
];
List<({String label, IconData icon, IconData selected})> get destinations =>
    isApple ? appleDestinations : materialDestinations;

class WallShell extends StatefulWidget {
  const WallShell({super.key});
  @override
  State<WallShell> createState() => _WallShellState();
}

class _WallShellState extends State<WallShell> {
  int index = 0;

  void select(int value) {
    haptic(context);
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rail = constraints.maxWidth >= 720 && constraints.maxHeight >= 600;
      final extended = constraints.maxWidth >= 1050;
      final state = AppScope.of(context);
      final body = IndexedStack(
        index: index,
        children: [
          const FeedPage(),
          const DiscoverPage(),
          if (index == 2)
            const SitePage(
              key: ValueKey('daily'),
              path: '/daily',
              embedded: true,
            )
          else
            const SizedBox(),
          const AccountPage(),
        ],
      );
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (rail)
                Container(
                  width: extended ? 208 : 88,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: .3),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          extended ? 22 : 20,
                          28,
                          extended ? 18 : 20,
                          30,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                CupertinoIcons.bubble_left_bubble_right_fill,
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                            if (extended) ...[
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '复兴校园墙',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'FUXING WALL',
                                      style: TextStyle(
                                        fontSize: 9,
                                        letterSpacing: 1.4,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (extended)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
                          child: Text(
                            '我们的校园',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      for (final (i, d) in destinations.indexed)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: extended ? 14 : 12,
                            vertical: 5,
                          ),
                          child: Tooltip(
                            message: d.label,
                            child: Material(
                              color: index == i
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: .6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => select(i),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: extended
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        index == i ? d.selected : d.icon,
                                        size: 21,
                                        color: index == i
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      if (extended) ...[
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            d.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: index == i
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (index == i)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: extended ? 22 : 14,
                        ),
                        child: FilledButton(
                          onPressed: () => openWallLink(context, '/post/new'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(44, 52),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.pencil, size: 18),
                              if (extended) ...[
                                const SizedBox(width: 10),
                                const Text(
                                  '写点什么',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (extended)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    openWallLink(context, '/compliance'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text(
                                  '隐私与内容合规',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                              const Text(
                                '小小的墙，\n装下大大的校园。',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  height: 1.9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
        bottomNavigationBar: rail
            ? null
            : SafeArea(
                top: false,
                child: isApple
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: GlassSurface(
                          native: state.glass,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 6,
                            ),
                            child: Row(
                              children: [
                                for (final (i, d) in destinations.indexed)
                                  Expanded(
                                    child: Semantics(
                                      selected: index == i,
                                      button: true,
                                      label: d.label,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () => select(i),
                                        child: AnimatedContainer(
                                          duration: motion(context),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: index == i
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: .1)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                index == i
                                                    ? d.selected
                                                    : d.icon,
                                                size: 22,
                                                color: index == i
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                d.label,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: index == i
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : NavigationBar(
                        selectedIndex: index,
                        onDestinationSelected: select,
                        animationDuration: motion(context),
                        height: 74,
                        destinations: destinations
                            .map(
                              (d) => NavigationDestination(
                                icon: Icon(d.icon, size: 23),
                                selectedIcon: Icon(d.selected, size: 23),
                                label: d.label,
                              ),
                            )
                            .toList(),
                      ),
              ),
      );
    },
  );
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const Eyebrow('EXPLORE YOUR CAMPUS'),
          const SizedBox(height: 12),
          Text('发现一点新鲜事', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            '从一个话题开始，遇见同频的你。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final item in [
                  ('表白', '把心动说出来', CupertinoIcons.heart, 0xFFF4E4E7),
                  ('闲聊', '日常的小小碎片', CupertinoIcons.chat_bubble_2, 0xFFE5ECF8),
                  ('求助', '总有人愿意帮忙', CupertinoIcons.hand_raised, 0xFFE8EEE5),
                  ('寻物', '让走失的物品回家', CupertinoIcons.search, 0xFFF4ECDF),
                  ('学习', '一起变得更好', CupertinoIcons.book, 0xFFECE7F5),
                  ('社团', '找到你的热爱', CupertinoIcons.person_2, 0xFFE1EFED),
                ])
                  SizedBox(
                    width:
                        (c.maxWidth - 14) / (c.maxWidth > 550 ? 3 : 2) -
                        (c.maxWidth > 550 ? 5 : 0),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => openWallLink(
                          context,
                          '/?q=${Uri.encodeComponent(item.$1)}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Color(item.$4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(item.$3, color: ink, size: 22),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                '# ${item.$1}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.$2,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('校园里的小惊喜'),
          _ExploreTile(
            icon: CupertinoIcons.sparkles,
            title: '今日小签',
            subtitle: '恋爱运和一句暖心话',
            path: '/daily',
          ),
          _ExploreTile(
            icon: CupertinoIcons.lightbulb,
            title: '你知道吗？',
            subtitle: '读一点不一样的内容',
            path: '/did-you-know',
          ),
          _ExploreTile(
            icon: CupertinoIcons.shuffle,
            title: '手气不错',
            subtitle: '随机遇见一条校园的声音',
            path: '/lucky-post',
          ),
          const SizedBox(height: 24),
          const SectionTitle('来之前，了解一下'),
          _ExploreTile(
            icon: CupertinoIcons.info,
            title: '入站须知',
            subtitle: '使用说明和社区规则',
            path: '/entry-notice',
          ),
          _ExploreTile(
            icon: CupertinoIcons.shield,
            title: '隐私与内容合规声明',
            subtitle: '了解信息处理和内容规则',
            path: '/compliance',
          ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}

class _ExploreTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, path;
  const _ExploreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 23,
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => openWallLink(context, path),
      ),
    ),
  );
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  Future<void> signOut(BuildContext context) async {
    final state = AppScope.of(context);
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (c) => AlertDialog.adaptive(
        title: const Text('退出登录？'),
        content: const Text('此设备上的登录状态和投稿草稿将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final form = state.session?.logoutForm;
      if (form != null) await state.repository.submit(form, form.values);
    } catch (_) {}
    await state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const Eyebrow('A SPACE THAT’S YOURS'),
            const SizedBox(height: 12),
            Text('我的小角落', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 26),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Icon(
                        CupertinoIcons.person_crop_circle,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.signedIn ? '今天也欢迎你' : '你好，同学',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            state.signedIn ? '匿名表达，自在做自己。' : '登录后，加入校园里的对话。',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!state.signedIn) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => openWallLink(context, '/login'),
                child: const Text('登录 / 创建账号'),
              ),
            ],
            const SectionTitle('我的校园'),
            const _ExploreTile(
              icon: CupertinoIcons.doc_text,
              title: '我的帖子',
              subtitle: '查看投稿、审核状态和评论提醒',
              path: '/my-posts',
            ),
            const _ExploreTile(
              icon: CupertinoIcons.bookmark,
              title: '我的收藏',
              subtitle: '留住值得再次读到的声音',
              path: '/favorites',
            ),
            const _ExploreTile(
              icon: CupertinoIcons.pencil,
              title: '继续写点什么',
              subtitle: '本机自动保存尚未提交的文字草稿',
              path: '/post/new',
            ),
            const SectionTitle('随你喜欢'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(CupertinoIcons.moon),
                    title: const Text('外观', style: TextStyle(fontSize: 14)),
                    trailing: DropdownButton<ThemeMode>(
                      value: state.themeMode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('跟随系统', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('浅色', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('深色', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      onChanged: (v) => state.setTheme(v!),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(CupertinoIcons.wind),
                    title: const Text('减少动态效果', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      '也会遵循系统的减少动态效果设置',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: state.reduceMotion,
                    onChanged: state.setReduceMotion,
                  ),
                  if (isApple)
                    SwitchListTile.adaptive(
                      secondary: const Icon(CupertinoIcons.drop),
                      title: const Text(
                        'Liquid Glass',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        '半透明导航与系统玻璃材质',
                        style: TextStyle(fontSize: 10),
                      ),
                      value: state.glass,
                      onChanged: state.setGlass,
                    ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.trash),
                    title: const Text('清除离线缓存', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      '下次联网浏览时重新获取',
                      style: TextStyle(fontSize: 10),
                    ),
                    onTap: () async {
                      await state.prefs.remove('publicFeed');
                      state.cachedPosts = [];
                      if (context.mounted) toast(context, '离线缓存已清除');
                    },
                  ),
                ],
              ),
            ),
            const SectionTitle('关于这里'),
            const _ExploreTile(
              icon: CupertinoIcons.info,
              title: '入站须知',
              subtitle: '友好交流，尊重隐私',
              path: '/entry-notice',
            ),
            const _ExploreTile(
              icon: CupertinoIcons.shield,
              title: '隐私与内容合规',
              subtitle: '网站的隐私和社区声明',
              path: '/compliance',
            ),
            if (state.signedIn)
              TextButton(
                onPressed: () => signOut(context),
                child: Text(
                  '退出登录',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 32),
            const Text(
              '复兴校园墙 · Flutter 客户端 1.0.1\n独立客户端，内容与账号由 fxlovewall.me 提供。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey, height: 2),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
