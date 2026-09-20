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
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
