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
      // The default "DEBUG" ribbon sits in the top-right corner and was
      // previously found covering an AppBar action icon placed there —
      // kept off even now that AppBanner lives top-left instead, since
      // debug builds already have their own signal (the "Use test
      // recipient" button, kDebugMode-gated).
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
