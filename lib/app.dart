import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class CbaEngineApp extends ConsumerWidget {
  const CbaEngineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // The browser tab's title on the web; web/index.html says the same.
      title: 'CBAEngine - email your local councillors',
      // The default "DEBUG" ribbon sits in the top-right corner and was
      // previously found covering an AppBar action icon placed there —
      // kept off even now that AppBanner lives top-left instead, since
      // debug builds already have their own signal (the "Use test
      // recipient" button, kDebugMode-gated).
      debugShowCheckedModeBanner: false,
      // One light theme: the app is not dark, whatever the device is set to.
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
