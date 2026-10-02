import 'dart:async';
import 'dart:convert';

import 'package:app/app.dart';
import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/lea.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('starting over from the review screen goes home without an error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        httpClientProvider.overrideWithValue(
          MockClient((request) async => http.Response(jsonEncode({'councils': <Object>[]}), 200)),
        ),
      ],
    );

    container.read(draftNotifierProvider.notifier)
      ..selectCouncil(const Council(id: 'fingal-county-council', name: 'Fingal County Council'))
      ..selectLea(
        const Lea(
          id: 'swords',
          name: 'Swords',
          council: 'Fingal County Council',
          councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
        ),
      )
      ..setTopic('housing')
      ..setSubject('Subject')
      ..setBody('Body');

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CbaEngineApp()));
    await tester.pumpAndSettle();

    // Pushed on top of home, as the real flow does — so leaving it plays
    // an exit animation, during which the screen is still built.
    unawaited(container.read(routerProvider).push('/review'));
    await tester.pumpAndSettle();
    expect(find.text('Swords, Fingal County Council'), findsOneWidget);

    await tester.tap(find.text('CBAEngine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();

    // Starting over empties the draft while the review screen is still
    // animating away; it must cope with that rather than fail to build.
    expect(tester.takeException(), isNull);
    expect(find.text('What would you like to do?'), findsOneWidget);
  });
}
