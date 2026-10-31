import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../state.dart';

const wallBlue = Color(0xFF4268DB);
const ink = Color(0xFF202A40);

/// Lightweight inline renderer for the website's deliberately small text format.
/// Unlike full article HTML layout, this supports a bounded five-line feed card.
class PostPreviewText extends StatefulWidget {
  final String html;
  const PostPreviewText(this.html, {super.key});
  @override
  State<PostPreviewText> createState() => _PostPreviewTextState();
}

class _PostPreviewTextState extends State<PostPreviewText> {
  late TextSpan content;
  @override
  void initState() {
    super.initState();
    content = parseContent(widget.html);
  }

  @override
  void didUpdateWidget(PostPreviewText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) content = parseContent(widget.html);
  }

  TextSpan parseContent(String html) {
    InlineSpan span(dom.Node node) {
      if (node is dom.Text) return TextSpan(text: node.text);
      if (node is! dom.Element) return const TextSpan();
      if (node.localName == 'br') return const TextSpan(text: '\n');
      final color = node.classes
          .where((c) => c.startsWith('post-color-'))
          .firstOrNull;
      return TextSpan(
        style: TextStyle(
          fontStyle: ['em', 'i'].contains(node.localName)
              ? FontStyle.italic
              : null,
          color: switch (color) {
            'post-color-blue' => const Color(0xFF5F78A8),
            'post-color-red' => const Color(0xFFB76565),
            'post-color-orange' => const Color(0xFFB5794C),
            'post-color-green' => const Color(0xFF628A6A),
            _ => null,
          },
        ),
        children: node.nodes.map(span).toList(),
      );
    }

    return TextSpan(
      children: html_parser.parseFragment(html).nodes.map(span).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    content,
    maxLines: 5,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.8),
  );
}

bool get isApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
bool motionOff(BuildContext context) =>
    AppScope.of(context).reduceMotion ||
    MediaQuery.disableAnimationsOf(context);
Duration motion(BuildContext context, [int milliseconds = 280]) =>
    Duration(milliseconds: motionOff(context) ? 0 : milliseconds);

ThemeData wallTheme(Brightness brightness, ColorScheme? dynamic) {
  final scheme =
      dynamic ??
      ColorScheme.fromSeed(seedColor: wallBlue, brightness: brightness);
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF10141D)
        : const Color(0xFFF5F7FC),
    fontFamily: isApple ? '.SF Pro Text' : null,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF1C2230) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16, height: 1.7),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool native;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 30,
    this.native = false,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled =
        isApple &&
        AppScope.of(context).glass &&
        !MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF242B3C) : Colors.white).withValues(
          alpha: enabled ? .72 : 1,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: (dark ? Colors.white : Colors.white).withValues(
            alpha: dark ? .12 : .85,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (!enabled || motionOff(context)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          if (native && defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb)
            const Positioned.fill(
              child: IgnorePointer(
                child: UiKitView(viewType: 'me.fxlove/liquid_glass'),
              ),
            )
          else
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const SizedBox.expand(),
              ),
            ),
          if (native && defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: child,
            )
          else
            surface,
        ],
      ),
    );
  }
}

class WallHtml extends StatelessWidget {
  final String html;
  final Future<void> Function(String)? onLink;
  final bool large;
  const WallHtml(this.html, {super.key, this.onLink, this.large = false});
  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    textStyle: Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: large ? 18 : 15, height: 1.75),
    onTapUrl: (url) async {
      if (onLink != null) {
        await onLink!(url);
        return true;
      }
      final uri = Uri.tryParse(url);
      if (uri != null && ['https', 'http'].contains(uri.scheme)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    },
    customStylesBuilder: (element) {
      final color = element.classes
          .where((c) => c.startsWith('post-color-'))
          .firstOrNull;
      if (color != null) {
        return {
          'color': switch (color) {
            'post-color-blue' => '#5f78a8',
            'post-color-red' => '#b76565',
            'post-color-orange' => '#b5794c',
            'post-color-green' => '#628a6a',
            _ => 'inherit',
          },
        };
      }
      if (element.localName == 'script' || element.localName == 'style') {
        return {'display': 'none'};
      }
      if (element.localName == 'h1') {
        return {'font-size': '28px', 'line-height': '1.4'};
      }
      if (element.localName == 'h2') {
        return {'font-size': '20px', 'line-height': '1.65'};
      }
      return null;
    },
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.2,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onRetry;
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.forum_outlined,
    this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ],
      ),
    ),
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

class Busy extends StatelessWidget {
  const Busy({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: isApple
        ? const CupertinoActivityIndicator()
        : const CircularProgressIndicator(strokeWidth: 2),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

void haptic(BuildContext context) {
  if (!motionOff(context)) HapticFeedback.selectionClick();
}
