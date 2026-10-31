import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state.dart';
import 'actions.dart';
import 'design.dart';
import 'forms.dart';
import 'navigation.dart';

class DailyContent extends StatefulWidget {
  final SiteDocument document;
  final Future<bool> Function(FormSpec, Map<String, String>) onSubmit;
  final Future<void> Function() onRefresh;
  const DailyContent({
    super.key,
    required this.document,
    required this.onSubmit,
    required this.onRefresh,
  });
  @override
  State<DailyContent> createState() => _DailyContentState();
}

class _DailyContentState extends State<DailyContent> {
  bool drawing = false;
  String? lucky;
  Future<void> drawLucky() async {
    if (drawing) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    final state = AppScope.of(context);
    setState(() => drawing = true);
    try {
      final home = await state.repository.load('/');
      state.accept(home);
      String message;
      if (home.luckyResult.isNotEmpty) {
        message = home.luckyResult;
      } else {
        final form = home.forms.firstWhere(
          (f) => f.action == '/daily-lucky-item',
        );
        final result = await state.repository.submit(
          form,
          form.values,
          ajax: true,
        );
        message = result.messages.join('\n');
      }
      if (mounted) {
        setState(() => lucky = message);
        haptic(context);
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => drawing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      const Eyebrow('TODAY’S LITTLE THINGS'),
      const SizedBox(height: 14),
      Text(
        '把一点好运\n装进口袋。',
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(height: 1.4),
      ),
      const SizedBox(height: 12),
      Text(
        '今天也不用太认真。\n抽一点也许刚好让你开心的东西。',
        style: TextStyle(
          fontSize: 13,
          height: 1.9,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 28),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 650 ? 2 : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (i, card) in widget.document.fortunes.indexed)
                SizedBox(
                  width: (c.maxWidth - 16 * (columns - 1)) / columns,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: card.love
                                    ? const Color(0xFFF6E4EA)
                                    : const Color(0xFFF4ECD9),
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: Icon(
                                card.love
                                    ? CupertinoIcons.heart
                                    : CupertinoIcons.sun_max,
                                color: card.love
                                    ? const Color(0xFFAD6C82)
                                    : const Color(0xFFB39155),
                                size: 27,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            card.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSize(
                            duration: motion(context, 350),
                            alignment: Alignment.topCenter,
                            child: WallHtml(
                              card.contentHtml,
                              onLink: (url) async {
                                await openWallLink(context, url);
                                await widget.onRefresh();
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (card.form != null)
                            NativeForm(
                              key: ValueKey('${widget.document.hashCode}-$i'),
                              spec: card.form!,
                              onSubmit: (v) => widget.onSubmit(card.form!, v),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      GlassSurface(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.gift,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '今日幸运物品',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lucky ?? '今天，会是什么陪你度过这一天？',
                style: const TextStyle(fontSize: 14, height: 1.8),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: drawing ? null : drawLucky,
                child: Text(
                  drawing
                      ? '正在抽取…'
                      : lucky == null
                      ? '看看我的幸运物品'
                      : '再看看今日结果',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        '小签仅供娱乐。恋爱运以北京时间每天 00:00 重置，结果由网站保存。',
        style: TextStyle(
          fontSize: 10,
          height: 1.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
