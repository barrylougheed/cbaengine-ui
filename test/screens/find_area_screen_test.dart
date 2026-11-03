import 'dart:async';
import 'dart:convert';

import 'package:app/app.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Find your area": type a town, village or suburb, pick the area it is in,
/// and carry straight on to writing the message.
void main() {
  late ProviderContainer container;
  late List<Map<String, dynamic>> searches;

  http.Response jsonResponse(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Map<String, dynamic> result(String place, String leaId, String leaName, String council, List<String> names) => {
    'place': place,
    'council_id': council.toLowerCase().replaceAll(' ', '-'),
    'lea': {
      'id': leaId,
      'name': leaName,
      'council': council,
      'councillors': [
        for (final name in names) {'name': name, 'party': 'Independent'},
      ],
    },
  };

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/places/search') {
      final asked = jsonDecode(request.body) as Map<String, dynamic>;
      searches.add(asked);
      switch ((asked['query'] as String).toLowerCase()) {
        case 'swords':
          return jsonResponse({
            'results': [result('Swords', 'fingal-swords', 'Swords', 'Fingal County Council', ['Ann One', 'Bob Two', 'Cora Three'])],
            'total': 1,
          });
        case 'athlone':
          return jsonResponse({
            'results': [
              result('Athlone', 'westmeath-athlone', 'Athlone', 'Westmeath County Council', ['Dan Four']),
              result('Athlone', 'roscommon-athlone', 'Athlone', 'Roscommon County Council', ['Eve Five', 'Finn Six']),
            ],
            'total': 2,
          });
        case 'newtown':
          return jsonResponse({
            'results': [
              for (var i = 0; i < 8; i++) result('Newtown', 'area-$i', 'Area $i', 'County $i Council', ['Cllr $i']),
            ],
            'total': 31,
          });
        case 'boom':
          return jsonResponse({'detail': 'down'}, 500);
        default:
          return jsonResponse({'results': <Object>[], 'total': 0});
      }
    }
    if (request.url.path == '/councils') {
      return jsonResponse({
        'councils': [
          {'id': 'carlow-county-council', 'name': 'Carlow County Council', 'area_count': 3, 'councillor_count': 18},
        ],
      });
    }
    return jsonResponse({});
  }

  Future<void> open(WidgetTester tester, {String path = '/find-area'}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    searches = [];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), httpClientProvider.overrideWithValue(MockClient(handle))],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CbaEngineApp()));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(path));
    await tester.pumpAndSettle();
  }

  /// Types, waits out the pause before searching, and lets the answer arrive.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for a town, village or suburb, and searches for nothing yet', (tester) async {
    await open(tester);

    expect(find.text('Find your area'), findsOneWidget);
    expect(find.textContaining('Type the town, village or suburb where you live'), findsOneWidget);
    expect(searches, isEmpty);
  });

  testWidgets('one letter is not searched for', (tester) async {
    await open(tester);

    await type(tester, 's');

    expect(searches, isEmpty);
  });

  testWidgets('shows the area a place is in, with its council and who the councillors are', (tester) async {
    await open(tester);

    await type(tester, 'Swords');

    expect(searches.single, {'query': 'Swords'});
    expect(find.text('Swords'), findsWidgets);
    expect(find.text('Swords, Fingal County Council'), findsOneWidget);
    expect(find.text('3 councillors'), findsOneWidget);
    expect(find.text('Ann One, Bob Two, Cora Three'), findsOneWidget);
  });

  testWidgets('choosing a result picks that council and area and goes on to the message', (tester) async {
    await open(tester);
    await type(tester, 'Swords');

    await tester.tap(find.text('Swords, Fingal County Council'));
    await tester.pumpAndSettle();

    final draft = container.read(draftNotifierProvider);
    expect(draft.council?.name, 'Fingal County Council');
    expect(draft.lea?.id, 'fingal-swords');
    expect(find.text('Select a topic'), findsOneWidget); // the Compose screen
  });

  testWidgets('a place in two areas shows both and asks which one their address is in', (tester) async {
    await open(tester);

    await type(tester, 'Athlone');

    expect(find.text('Athlone, Westmeath County Council'), findsOneWidget);
    expect(find.text('Athlone, Roscommon County Council'), findsOneWidget);
    expect(find.text('Pick the area your address is in.'), findsOneWidget);
  });

  testWidgets('a name with many matches says so and asks for more of the name', (tester) async {
    await open(tester);

    await type(tester, 'Newtown');

    expect(find.text('Showing 8 of 31 matches. Type more of the name to narrow it down.'), findsOneWidget);
  });

  testWidgets('no match says so and offers the list of councils instead', (tester) async {
    await open(tester);

    await type(tester, 'Narnia');

    expect(find.textContaining('We could not find "Narnia"'), findsOneWidget);

    await tester.tap(find.text('Choose from the list of councils'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Select your council'), findsOneWidget);
  });

  testWidgets('a failed search says so and can be retried', (tester) async {
    await open(tester);

    await type(tester, 'boom');

    expect(find.textContaining('Could not search'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('credits where the boundaries and place names come from', (tester) async {
    await open(tester);

    expect(find.textContaining('Tailte Éireann'), findsOneWidget);
  });

  testWidgets('the council list offers it, above the councils', (tester) async {
    await open(tester, path: '/council');

    expect(find.text('Not sure? Find your area'), findsOneWidget);
    expect(find.text('Enter your town, village or suburb'), findsOneWidget);

    await tester.tap(find.text('Not sure? Find your area'));
    await tester.pumpAndSettle();

    expect(find.text('Find your area'), findsOneWidget);
  });
}
