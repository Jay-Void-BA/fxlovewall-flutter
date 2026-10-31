import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

class TextMark {
  int start, end;
  final String? color;
  final bool italic;
  TextMark(this.start, this.end, {this.color, this.italic = false});
}

class WallEditorController extends TextEditingController {
  final List<TextMark> marks = [];
  String previous = '';
  WallEditorController(String source) {
    final d = html.parseFragment(source);
    final buffer = StringBuffer();
    void visit(dom.Node node, String? color, bool italic) {
      if (node is dom.Text) {
        final start = buffer.length;
        buffer.write(node.text);
        if (color != null || italic) {
          marks.add(
            TextMark(start, buffer.length, color: color, italic: italic),
          );
        }
      } else if (node is dom.Element) {
        if (node.localName == 'br') {
          buffer.write('\n');
          return;
        }
        final c = node.classes
            .where((x) => x.startsWith('post-color-'))
            .firstOrNull
            ?.replaceFirst('post-color-', '');
        for (final child in node.nodes) {
          visit(
            child,
            c ?? color,
            italic || ['em', 'i'].contains(node.localName),
          );
        }
        if (['div', 'p'].contains(node.localName) &&
            buffer.isNotEmpty &&
            !buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
      }
    }

    for (final n in d.nodes) {
      visit(n, null, false);
    }
    text = buffer.toString();
    previous = text;
    addListener(_shiftMarks);
  }
  void _shiftMarks() {
    final current = text;
    if (current == previous) return;
    var start = 0;
    while (start < previous.length &&
        start < current.length &&
        previous[start] == current[start]) {
      start++;
    }
    var oldEnd = previous.length, newEnd = current.length;
    while (oldEnd > start &&
        newEnd > start &&
        previous[oldEnd - 1] == current[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    final delta = newEnd - oldEnd;
    for (final m in marks) {
      if (m.end <= start) continue;
      if (m.start >= oldEnd) {
        m.start += delta;
        m.end += delta;
      } else {
        m.start = m.start.clamp(0, start);
        m.end = (m.end + delta).clamp(m.start, current.length);
      }
    }
    marks.removeWhere((m) => m.end <= m.start);
    previous = current;
  }

  void format({String? color, bool italic = false, bool clear = false}) {
    final selection = this.selection;
    final start = selection.isValid && !selection.isCollapsed
        ? selection.start
        : 0;
    final end = selection.isValid && !selection.isCollapsed
        ? selection.end
        : text.length;
    if (end <= start) return;
    if (clear) {
      final keep = <TextMark>[];
      for (final m in marks) {
        if (m.end <= start || m.start >= end) {
          keep.add(m);
          continue;
        }
        if (m.start < start) {
          keep.add(TextMark(m.start, start, color: m.color, italic: m.italic));
        }
        if (m.end > end) {
          keep.add(TextMark(end, m.end, color: m.color, italic: m.italic));
        }
      }
      marks
        ..clear()
        ..addAll(keep);
    } else {
      marks.add(TextMark(start, end, color: color, italic: italic));
    }
    notifyListeners();
  }

  Iterable<({String text, String? color, bool italic})> get segments sync* {
    final points = <int>{0, text.length};
    for (final m in marks) {
      points.add(m.start.clamp(0, text.length));
      points.add(m.end.clamp(0, text.length));
    }
    final sorted = points.toList()..sort();
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i], end = sorted[i + 1];
      String? color;
      var italic = false;
      for (final m in marks) {
        if (m.start <= start && m.end >= end) {
          color = m.color ?? color;
          italic = italic || m.italic;
        }
      }
      yield (text: text.substring(start, end), color: color, italic: italic);
    }
  }

  String toHtml() => segments.map((s) {
    var value = const HtmlEscape().convert(s.text).replaceAll('\n', '<br>');
    if (s.italic) value = '<em>$value</em>';
    if (s.color != null) {
      final hex = switch (s.color) {
        'blue' => '#5f78a8',
        'red' => '#b76565',
        'orange' => '#b5794c',
        'green' => '#628a6a',
        _ => '',
      };
      value =
          '<span class="post-color-${s.color}" style="color:$hex">$value</span>';
    }
    return value;
  }).join();
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => TextSpan(
    style: style,
    children: segments
        .map(
          (s) => TextSpan(
            text: s.text,
            style: TextStyle(
              fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
              color: switch (s.color) {
                'blue' => const Color(0xFF5F78A8),
                'red' => const Color(0xFFB76565),
                'green' => const Color(0xFF628A6A),
                'orange' => const Color(0xFFB5794C),
                _ => null,
              },
            ),
          ),
        )
        .toList(),
  );
}

class EditorToolbar extends StatelessWidget {
  final WallEditorController controller;
  const EditorToolbar({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 2,
    children: [
      IconButton(
        tooltip: '所选文字恢复正文；未选择时应用全文',
        onPressed: () => controller.format(clear: true),
        icon: const Icon(Icons.format_clear),
      ),
      IconButton(
        tooltip: '斜体',
        onPressed: () => controller.format(italic: true),
        icon: const Icon(Icons.format_italic),
      ),
      for (final c in [
        ('orange', const Color(0xFFB5794C), '橙色'),
        ('red', const Color(0xFFB76565), '红色'),
        ('blue', const Color(0xFF5F78A8), '蓝色'),
        ('green', const Color(0xFF628A6A), '绿色'),
      ])
        IconButton(
          tooltip: c.$3,
          onPressed: () => controller.format(color: c.$1),
          icon: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(color: c.$2, shape: BoxShape.circle),
          ),
        ),
    ],
  );
}
