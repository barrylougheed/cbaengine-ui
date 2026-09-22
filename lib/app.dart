import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class CbaEngineApp extends ConsumerWidget {
  const CbaEngineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CBAEngine',
      // The default "DEBUG" ribbon sits directly over an AppBar's
      // top-right action icon — exactly where HomeAction lives on every
      // step screen — visually hiding and blocking taps on it. Debug
      // builds already have their own signal (the "Use test recipient"
      // button, kDebugMode-gated), so the banner isn't pulling its
      // weight here.
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
