import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class DailyAskingApp extends StatelessWidget {
  const DailyAskingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Daily Asking',
      debugShowCheckedModeBanner: false,
      theme: buildDailyAskingTheme(Brightness.light),
      darkTheme: buildDailyAskingTheme(Brightness.dark),
      routerConfig: appRouter,
    );
  }
}
