import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/models.dart';
import 'data/repository.dart';

class AppState extends ChangeNotifier {
  final WallRepository repository;
  final SharedPreferences prefs;
  bool signedIn = false;
  bool reduceMotion;
  bool glass;
  ThemeMode themeMode;
  SiteDocument? session;
  List<WallPost> cachedPosts = [];
  DateTime? cachedAt;
  String? draft;
  AppState(this.repository, this.prefs)
    : reduceMotion = prefs.getBool('reduceMotion') ?? false,
      glass = prefs.getBool('glass') ?? true,
      themeMode =
          ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(
            0,
            ThemeMode.values.length - 1,
          )] {
    try {
      final raw = prefs.getString('publicFeed');
      if (raw != null) {
        final j = jsonDecode(raw);
        cachedPosts = (j['posts'] as List)
            .map((e) => WallPost.fromJson(e))
            .toList();
        cachedAt = DateTime.tryParse(j['time']);
      }
    } catch (_) {
      cachedPosts = [];
    }
    draft = prefs.getString('draft');
  }
  void accept(SiteDocument doc) {
    // A small JSON response carries no session metadata.
    if (doc.title.isEmpty && doc.navigation.isEmpty) return;
    final changed = signedIn != doc.signedIn;
    signedIn = doc.signedIn;
    session = doc;
    if (changed) notifyListeners();
  }

  Future<void> cacheFeed(List<WallPost> posts) async {
    cachedPosts = posts;
    cachedAt = DateTime.now();
    await prefs.setString(
      'publicFeed',
      jsonEncode({
        'time': cachedAt!.toIso8601String(),
        'posts': posts.take(100).map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> setTheme(ThemeMode v) async {
    themeMode = v;
    notifyListeners();
    await prefs.setInt('theme', v.index);
  }

  Future<void> setReduceMotion(bool v) async {
    reduceMotion = v;
    notifyListeners();
    await prefs.setBool('reduceMotion', v);
  }

  Future<void> setGlass(bool v) async {
    glass = v;
    notifyListeners();
    await prefs.setBool('glass', v);
  }

  Future<void> saveDraft(String text) async {
    draft = text;
    await prefs.setString('draft', text);
  }

  Future<void> clearDraft() async {
    draft = null;
    await prefs.remove('draft');
  }

  Future<void> signOut() async {
    await repository.clearSession();
    signedIn = false;
    session = null;
    await clearDraft();
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
