import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repository.dart';
import 'data/appearance.dart';
import 'state.dart';
import 'ui/design.dart';
import 'ui/shell.dart';
import 'ui/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(WallRepository(), prefs);
  runApp(CampusWallApp(state: state));
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await state.appearance.recoverLostPhoto();
    } catch (_) {
      // Startup recovery must not prevent browsing the wall.
    }
  });
}

class CampusWallApp extends StatefulWidget {
  final AppState state;
  const CampusWallApp({super.key, required this.state});
  @override
  State<CampusWallApp> createState() => _CampusWallAppState();
}

class _CampusWallAppState extends State<CampusWallApp> {
  AppState get state => widget.state;
  final Map<Brightness, ({Object key, ThemeData theme})> _themes = {};
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (phase) {
        if (phase == AppLifecycleState.inactive ||
            phase == AppLifecycleState.hidden ||
            phase == AppLifecycleState.paused) {
          unawaited(state.appearance.flush().catchError((Object _) {}));
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: ListenableBuilder(
      listenable: Listenable.merge([state, state.appearance]),
      builder: (context, _) => DynamicColorBuilder(
        builder: (light, dark) => MaterialApp(
          title: '复兴校园墙',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light, light),
          darkTheme: _theme(Brightness.dark, dark),
          themeMode: state.themeMode,
          themeAnimationDuration: state.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 280),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  state.reduceMotion || MediaQuery.disableAnimationsOf(context),
            ),
            child: WallBackgroundLayer(child: child!),
          ),
          home: const WallShell(),
        ),
      ),
    ),
  );

  ThemeData _theme(Brightness brightness, ColorScheme? system) {
    final appearance = state.appearance;
    final seed = switch (appearance.palette) {
      WallPalette.system => null,
      WallPalette.wallpaper => appearance.backgroundSeed,
      WallPalette.custom => appearance.customSeed,
    };
    final nativeColors = appearance.palette == WallPalette.system && !isApple
        ? system
        : null;
    final key = (seed, nativeColors, appearance.hasBackground, isApple);
    final cached = _themes[brightness];
    if (cached?.key == key) return cached!.theme;
    // Overlay changes and image import progress reuse both themes; only a new
    // seed or surface configuration needs Material's tonal palette generation.
    final colors = seed == null
        ? nativeColors
        : ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final theme = wallTheme(
      brightness,
      colors,
      hasBackground: appearance.hasBackground,
    );
    _themes[brightness] = (key: key, theme: theme);
    return theme;
  }
}
