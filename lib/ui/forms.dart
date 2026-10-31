import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state.dart';
import 'editor.dart';

class NativeForm extends StatefulWidget {
  final FormSpec spec;
  final Future<bool> Function(Map<String, String>) onSubmit;
  const NativeForm({super.key, required this.spec, required this.onSubmit});
  @override
  State<NativeForm> createState() => _NativeFormState();
}

class _NativeFormState extends State<NativeForm> {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final checks = <String, bool>{};
  final selects = <String, String>{};
  bool busy = false, obscured = true, initialized = false;
  String? error;
  Timer? timer;
  AppState? appState;
  bool get isComposer => widget.spec.fields.any((f) => f.type == 'editor');
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    appState = AppScope.of(context);
    Map<String, dynamic> draft = {};
    if (isComposer && widget.spec.action.startsWith('/post/new')) {
      try {
        draft = jsonDecode(AppScope.of(context).draft ?? '{}');
      } catch (_) {}
    }
    for (final f in widget.spec.fields) {
      if (f.type == 'checkbox') {
        checks[f.name] = draft[f.name] ?? f.checked;
      } else if (f.type == 'select') {
        selects[f.name] = f.value;
      } else if (f.type != 'hidden') {
        controllers[f.name] = f.type == 'editor'
            ? WallEditorController(draft[f.name] ?? f.value)
            : TextEditingController(text: draft[f.name] ?? f.value);
        if (isComposer) controllers[f.name]!.addListener(saveDraft);
      }
    }
  }

  void saveDraft() {
    if (!isComposer || !widget.spec.action.startsWith('/post/new')) return;
    final state = appState!;
    final snapshot = draftSnapshot();
    state.draft = snapshot;
    timer?.cancel();
    timer = Timer(
      const Duration(milliseconds: 500),
      () => state.saveDraft(snapshot),
    );
  }

  String draftSnapshot() => jsonEncode({
    for (final e in controllers.entries)
      e.key: e.value is WallEditorController
          ? (e.value as WallEditorController).toHtml()
          : e.value.text,
    ...checks,
  });

  @override
  void dispose() {
    timer?.cancel();
    if (!busy &&
        isComposer &&
        widget.spec.action.startsWith('/post/new') &&
        appState != null) {
      unawaited(appState!.saveDraft(draftSnapshot()));
    }
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final state = AppScope.of(context);
    if (widget.spec.action.contains('/delete') ||
        widget.spec.label.contains('删除')) {
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: const Text('确认删除？'),
          content: const Text('删除后可能无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (isComposer) {
        timer?.cancel();
        await state.saveDraft(draftSnapshot());
      }
      final values = <String, String>{};
      for (final f in widget.spec.fields) {
        if (f.type == 'checkbox') {
          if (checks[f.name] == true) values[f.name] = f.value;
        } else if (f.type == 'select') {
          values[f.name] = selects[f.name] ?? f.value;
        } else if (f.type == 'hidden') {
          values[f.name] = f.value;
        } else {
          final c = controllers[f.name]!;
          values[f.name] = c is WallEditorController ? c.toHtml() : c.text;
        }
      }
      final success = await widget.onSubmit(values);
      if (success && isComposer) {
        timer?.cancel();
        await state.clearDraft();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in spec.fields)
              if (f.type != 'hidden') ...[
                if (f.type == 'checkbox')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.label),
                    value: checks[f.name] ?? false,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() => checks[f.name] = v!);
                            saveDraft();
                          },
                  )
                else if (f.type == 'select')
                  DropdownButtonFormField<String>(
                    initialValue: selects[f.name],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: f.label),
                    items: f.options
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.href,
                            child: Text(o.label),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => selects[f.name] = v!,
                  )
                else ...[
                  if (f.type == 'editor') ...[
                    const SizedBox(height: 8),
                    EditorToolbar(
                      controller: controllers[f.name]! as WallEditorController,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        '选中文字可设置样式；未选择时应用全文。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: controllers[f.name],
                    enabled: !busy,
                    obscureText: f.type == 'password' && obscured,
                    minLines: f.type == 'editor'
                        ? 7
                        : f.type == 'textarea'
                        ? 3
                        : 1,
                    maxLines: ['editor', 'textarea'].contains(f.type)
                        ? null
                        : 1,
                    maxLength: f.maxLength,
                    keyboardType: ['editor', 'textarea'].contains(f.type)
                        ? TextInputType.multiline
                        : f.type == 'password'
                        ? TextInputType.visiblePassword
                        : TextInputType.text,
                    textInputAction: ['editor', 'textarea'].contains(f.type)
                        ? TextInputAction.newline
                        : TextInputAction.next,
                    autocorrect: f.type != 'password' && f.name != 'username',
                    autofillHints: f.name == 'username'
                        ? const [AutofillHints.username]
                        : f.type == 'password'
                        ? [
                            spec.action.contains('register')
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ]
                        : null,
                    decoration: InputDecoration(
                      labelText: f.label,
                      hintText: f.placeholder,
                      alignLabelWithHint: true,
                      suffixIcon: f.type == 'password'
                          ? IconButton(
                              tooltip: obscured ? '显示密码' : '隐藏密码',
                              onPressed: () =>
                                  setState(() => obscured = !obscured),
                              icon: Icon(
                                obscured
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            )
                          : null,
                    ),
                    validator: (v) {
                      if ((f.required || f.type == 'editor') &&
                          (v == null || v.trim().isEmpty)) {
                        return '请填写${f.label}';
                      }
                      if (v != null &&
                          f.minLength != null &&
                          v.length < f.minLength!) {
                        return '至少需要 ${f.minLength} 个字符';
                      }
                      if (f.name == 'password2' &&
                          v != controllers['password']?.text) {
                        return '两次输入的密码不一致';
                      }
                      if (f.name == 'tags' &&
                          v != null &&
                          v
                                  .split(RegExp('[,，]'))
                                  .where((e) => e.trim().isNotEmpty)
                                  .length >
                              3) {
                        return '最多填写 3 个标签';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            if (isComposer)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '草稿保存在本机 · 投稿审核通过后公开',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : submit,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(spec.label),
            ),
            if (spec.fields.any((f) => f.type == 'password'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '账号名仅用于登录，公开页面只显示匿名编号。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
