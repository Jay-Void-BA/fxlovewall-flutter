import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/appearance.dart';
import '../state.dart';
import 'design.dart';

const _backgroundNames = {
  WallBackground.classic: '经典',
  WallBackground.dawn: '晨曦',
  WallBackground.forest: '森林',
  WallBackground.dusk: '暮色',
  WallBackground.photo: '照片',
};

const _themeColors = [
  ('校园蓝', Color(0xFF4268DB)),
  ('鸢尾紫', Color(0xFF8661C5)),
  ('蔷薇粉', Color(0xFFBE6686)),
  ('落日橙', Color(0xFFBA7137)),
  ('银杏黄', Color(0xFF9C8427)),
  ('松林绿', Color(0xFF397863)),
  ('湖水青', Color(0xFF377F8B)),
  ('岩石灰', Color(0xFF647184)),
];

double _veilAlpha(AppearanceSettings settings, bool dark) =>
    ((dark ? .66 : .62) + settings.overlay * (dark ? .35 : .375)).clamp(
      0.0,
      .94,
    );

int _softeningPercent(AppearanceSettings settings) =>
    (settings.overlay / .8 * 100).round();

Future<void> _applyAppearanceChange(
  BuildContext context,
  Future<void> Function() change,
) async {
  try {
    await change();
  } catch (_) {
    if (context.mounted) toast(context, '设置未能保存，请重试');
  }
}

/// A single static surface under the navigator, shared by every route.
class WallBackgroundLayer extends StatelessWidget {
  final Widget child;
  const WallBackgroundLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).appearance;
    return ListenableBuilder(
      listenable: settings,
      child: child,
      builder: (context, child) {
        if (!settings.hasBackground) return child!;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final contrast = MediaQuery.highContrastOf(context);
        final veil = dark ? const Color(0xFF10141D) : Colors.white;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: contrast
                        ? ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              _BackgroundPaint(
                                background: settings.background,
                                photoPath: settings.photoPath,
                              ),
                              ColoredBox(
                                color: veil.withValues(
                                  alpha: _veilAlpha(settings, dark),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}

class _BackgroundPaint extends StatelessWidget {
  final WallBackground background;
  final String? photoPath;
  const _BackgroundPaint({required this.background, this.photoPath});

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              backgroundGradients[background] ??
              backgroundGradients[WallBackground.dawn]!,
        ),
      ),
    );
    if (background == WallBackground.classic) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    if (background != WallBackground.photo || photoPath == null) {
      return fallback;
    }
    final size = MediaQuery.sizeOf(context);
    final cacheWidth =
        (size.longestSide * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 1600);
    return Image.file(
      File(photoPath!),
      key: ValueKey(photoPath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  Future<void> _importPhoto(
    BuildContext context,
    AppearanceSettings settings,
  ) async {
    try {
      final changed = await settings.importPhoto();
      if (changed && context.mounted) toast(context, '背景已更换');
    } catch (error) {
      if (context.mounted) toast(context, error.toString());
    }
  }

  Future<void> _reset(BuildContext context, AppearanceSettings settings) async {
    try {
      await settings.restoreDefaults();
      if (context.mounted) toast(context, '已恢复默认背景与配色');
    } catch (_) {
      if (context.mounted) toast(context, '暂时无法重置，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).appearance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('背景与配色')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                key: const PageStorageKey('appearance-settings'),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                children: [
                  const Eyebrow('MAKE IT YOURS'),
                  const SizedBox(height: 10),
                  Text(
                    '让校园墙，\n有你的颜色。',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '选一张喜欢的背景，让配色随之变化。',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  _AppearancePreview(settings: settings),
                  const SectionTitle('更换背景'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 680
                                  ? 5
                                  : constraints.maxWidth >= 440
                                  ? 3
                                  : 2;
                              final width =
                                  (constraints.maxWidth - (columns - 1) * 10) /
                                  columns;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 12,
                                children: [
                                  for (final background
                                      in WallBackground.values)
                                    SizedBox(
                                      width: width,
                                      child: _BackgroundChoice(
                                        background: background,
                                        settings: settings,
                                        onSelected: () {
                                          if (background ==
                                                  WallBackground.photo &&
                                              settings.photoPath == null) {
                                            _importPhoto(context, settings);
                                          } else {
                                            _applyAppearanceChange(
                                              context,
                                              () => settings.setBackground(
                                                background,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          FilledButton.tonalIcon(
                            key: const ValueKey('choose-background-photo'),
                            onPressed: settings.importing
                                ? null
                                : () => _importPhoto(context, settings),
                            icon: settings.importing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(CupertinoIcons.photo),
                            label: Text(
                              settings.importing ? '正在处理照片…' : '从相册选择背景',
                            ),
                          ),
                          if (settings.photoPath != null)
                            TextButton.icon(
                              key: const ValueKey('remove-background-photo'),
                              onPressed: settings.importing
                                  ? null
                                  : () => _applyAppearanceChange(
                                      context,
                                      settings.clearPhoto,
                                    ),
                              icon: const Icon(CupertinoIcons.trash, size: 18),
                              label: const Text('删除保存的照片'),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            '照片只保存在这台设备，不会上传。',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (settings.hasBackground) ...[
                            const SizedBox(height: 18),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(child: Text('阅读柔化')),
                                Text('${_softeningPercent(settings)}%'),
                              ],
                            ),
                            Slider.adaptive(
                              key: const ValueKey('background-overlay'),
                              value: settings.overlay / .8,
                              min: 0,
                              max: 1,
                              divisions: 16,
                              label: '${_softeningPercent(settings)}%',
                              onChanged: (value) =>
                                  settings.setOverlay(value * .8),
                            ),
                            Text(
                              '调高后背景更柔和，文字更清晰。',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SectionTitle('主题配色'),
                  Card(
                    child: Column(
                      children: [
                        for (final option in [
                          (
                            WallPalette.system,
                            '跟随系统',
                            'Android 12 及以上使用系统壁纸配色，其他系统使用默认配色',
                          ),
                          (
                            WallPalette.wallpaper,
                            '背景莫奈取色',
                            '从当前背景生成协调的按钮、标签与主题色',
                          ),
                          (WallPalette.custom, '自选主题色', '选择一种喜欢的颜色'),
                        ])
                          _PaletteChoice(
                            value: option.$1,
                            title: option.$2,
                            subtitle: option.$3,
                            settings: settings,
                          ),
                        if (settings.palette == WallPalette.custom)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final (name, color) in _themeColors)
                                  Semantics(
                                    label: name,
                                    button: true,
                                    selected: settings.customSeed == color,
                                    child: Tooltip(
                                      message: name,
                                      child: Material(
                                        color: color,
                                        shape: CircleBorder(
                                          side: BorderSide(
                                            color: settings.customSeed == color
                                                ? scheme.onSurface
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: InkWell(
                                          key: ValueKey('theme-color-$name'),
                                          customBorder: const CircleBorder(),
                                          onTap: () => _applyAppearanceChange(
                                            context,
                                            () => settings.setCustomSeed(color),
                                          ),
                                          child: SizedBox.square(
                                            dimension: 48,
                                            child: settings.customSeed == color
                                                ? Icon(
                                                    Icons.check,
                                                    color:
                                                        ThemeData.estimateBrightnessForColor(
                                                              color,
                                                            ) ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PalettePreview(scheme: scheme),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const ValueKey('reset-appearance'),
                    onPressed: settings.importing
                        ? null
                        : () => _reset(context, settings),
                    icon: const Icon(CupertinoIcons.arrow_counterclockwise),
                    label: const Text('恢复默认背景与配色'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundChoice extends StatelessWidget {
  final WallBackground background;
  final AppearanceSettings settings;
  final VoidCallback onSelected;
  const _BackgroundChoice({
    required this.background,
    required this.settings,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = settings.background == background;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${_backgroundNames[background]}背景',
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('background-${background.name}'),
          onTap: settings.importing ? null : onSelected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _BackgroundPaint(
                      background: background,
                      photoPath: settings.photoPath,
                    ),
                    if (background == WallBackground.photo &&
                        settings.photoPath == null)
                      const Center(child: Icon(CupertinoIcons.photo, size: 28)),
                    if (background == WallBackground.classic)
                      Center(
                        child: Icon(
                          CupertinoIcons.square_grid_2x2,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_backgroundNames[background]!)),
                    if (selected)
                      Icon(Icons.check_circle, size: 18, color: scheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  final WallPalette value;
  final String title, subtitle;
  final AppearanceSettings settings;
  const _PaletteChoice({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final selected = settings.palette == value;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        key: ValueKey('palette-${value.name}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        onTap: () =>
            _applyAppearanceChange(context, () => settings.setPalette(value)),
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  final AppearanceSettings settings;
  const _AppearancePreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: '当前背景与主题预览',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height:
              204 *
              (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 3.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _BackgroundPaint(
                background: settings.background,
                photoPath: settings.photoPath,
              ),
              ColoredBox(
                color: (dark ? Colors.black : Colors.white).withValues(
                  alpha: _veilAlpha(settings, dark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Material(
                    color: scheme.surface.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今天，也要开心。',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          const Text('记录此刻的心情，遇见校园里的声音。'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.heart_fill,
                                color: scheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  '我们的校园',
                                  style: TextStyle(color: scheme.primary),
                                ),
                              ),
                            ],
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
    );
  }
}

class _PalettePreview extends StatelessWidget {
  final ColorScheme scheme;
  const _PalettePreview({required this.scheme});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (label, background, foreground) in [
        ('主题色', scheme.primary, scheme.onPrimary),
        ('辅助色', scheme.secondaryContainer, scheme.onSecondaryContainer),
        ('点缀色', scheme.tertiaryContainer, scheme.onTertiaryContainer),
        ('内容底色', scheme.surfaceContainerHigh, scheme.onSurface),
      ])
        Chip(
          label: Text(label, style: TextStyle(color: foreground)),
          backgroundColor: background,
          side: BorderSide.none,
        ),
    ],
  );
}
