import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import 'design.dart';

class PostCard extends StatelessWidget {
  final WallPost post;
  final VoidCallback onOpen;
  final VoidCallback? onLike, onShare, onFavorite;
  final ValueChanged<String>? onTag;
  final bool selected, busy;
  const PostCard({
    super.key,
    required this.post,
    required this.onOpen,
    this.onLike,
    this.onShare,
    this.onFavorite,
    this.onTag,
    this.selected = false,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return RepaintBoundary(
      child: Card(
        child: AnimatedContainer(
          duration: motion(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: .65)
                  : theme.colorScheme.outlineVariant.withValues(alpha: .25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CupertinoIcons.bubble_left_bubble_right,
                          size: 18,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '匿名 #${post.id}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              post.time,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (post.favorited)
                        Icon(Icons.bookmark_rounded, size: 18, color: primary),
                      IconButton(
                        tooltip: '打开帖子',
                        onPressed: onOpen,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_horiz, size: 20),
                      ),
                    ],
                  ),
                  if (post.controversial)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: .5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 15),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '该帖可能存在争议，请理性看待',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (post.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: post.tags
                            .map(
                              (tag) => ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '# $tag',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                side: BorderSide.none,
                                backgroundColor: primary.withValues(alpha: .07),
                                onPressed: () => onTag?.call(tag),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 13, bottom: 12),
                    child: PostPreviewText(post.contentHtml),
                  ),
                  if (post.text.length > 120)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '展开全文',
                        style: TextStyle(fontSize: 12, color: primary),
                      ),
                    ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .35,
                    ),
                  ),
                  Row(
                    children: [
                      _Action(
                        icon: post.liked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        label: '${post.likes}',
                        tooltip: '点赞',
                        active: post.liked,
                        onTap: busy ? null : onLike,
                      ),
                      const SizedBox(width: 10),
                      _Action(
                        icon: CupertinoIcons.chat_bubble,
                        label: '${post.comments}',
                        tooltip: '查看评论',
                        onTap: onOpen,
                      ),
                      const Spacer(),
                      if (onFavorite != null)
                        _Action(
                          icon: post.favorited
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          tooltip: post.favorited ? '取消收藏' : '收藏',
                          active: post.favorited,
                          onTap: busy ? null : onFavorite,
                        ),
                      if (post.shareable)
                        _Action(
                          icon: CupertinoIcons.arrowshape_turn_up_right,
                          tooltip: '分享',
                          onTap: onShare,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;
  const _Action({
    required this.icon,
    this.label,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    ),
  );
}
