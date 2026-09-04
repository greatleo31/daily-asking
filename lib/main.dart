/// 留痕 —— 本地优先的职场证据成长助手。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_state.dart';
import 'app/shell.dart';
import 'app/theme.dart';
import 'settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = await AppState.create();
  await appState.bootstrap();
  runApp(DailyAskingApp(appState: appState));
}

class DailyAskingApp extends StatelessWidget {
  const DailyAskingApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: Builder(
        builder: (context) {
          final themePref = context.select((AppState s) => s.theme);
          final mode = switch (themePref) {
            ThemeModePreference.system => ThemeMode.system,
            ThemeModePreference.light => ThemeMode.light,
            ThemeModePreference.dark => ThemeMode.dark,
          };
          return MaterialApp(
            title: '留痕',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: mode,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}