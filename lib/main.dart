import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repository.dart';
import 'state.dart';
import 'ui/design.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(CampusWallApp(state: AppState(WallRepository(), prefs)));
}

class CampusWallApp extends StatelessWidget {
  final AppState state;
  const CampusWallApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => DynamicColorBuilder(
        builder: (light, dark) => MaterialApp(
          title: '复兴校园墙',
          debugShowCheckedModeBanner: false,
          theme: wallTheme(Brightness.light, isApple ? null : light),
          darkTheme: wallTheme(Brightness.dark, isApple ? null : dark),
          themeMode: state.themeMode,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  state.reduceMotion || MediaQuery.disableAnimationsOf(context),
            ),
            child: child!,
          ),
          home: const WallShell(),
        ),
      ),
    ),
  );
}
