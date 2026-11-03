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

/// Step 1: with all 31 councils the list is long, so it has a visible
/// scrollbar and a search box (a screen that merely scrolls gave no sign that
/// there was more below the fold).
void main() {
  const names = [
    'Carlow County Council',
    'Dublin City Council',
    'Dún Laoghaire-Rathdown County Council',
    'Fingal County Council',
    'Galway City Council',
    'Galway County Council',
    'Wicklow County Council',
  ];

  late ProviderContainer container;

  http.Response jsonResponse(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/councils') {
      return jsonResponse({
        'councils': [
          for (final name in names) {'id': name.toLowerCase().replaceAll(' ', '-'), 'name': name},
        ],
      });
    }
    return jsonResponse({'leas': <Object>[]});
  }

  Future<void> openCouncilPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), httpClientProvider.overrideWithValue(MockClient(handle))],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CbaEngineApp()));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push('/council'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('lists every council and offers a search box', (tester) async {
    await openCouncilPicker(tester);

    for (final name in names) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search councils'), findsOneWidget);
  });

  testWidgets('the list has a scrollbar that is always showing, so it is clear there is more', (tester) async {
    await openCouncilPicker(tester);

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isTrue);
  });

  testWidgets('typing narrows the list, ignoring case and accents', (tester) async {
    await openCouncilPicker(tester);

    await search(tester, 'galway');
    expect(find.text('Galway City Council'), findsOneWidget);
    expect(find.text('Galway County Council'), findsOneWidget);
    expect(find.text('Carlow County Council'), findsNothing);

    await search(tester, 'DUN lao');
    expect(find.text('Dún Laoghaire-Rathdown County Council'), findsOneWidget);
    expect(find.text('Galway City Council'), findsNothing);
  });

  testWidgets('a search with no match says so, and clearing it brings the list back', (tester) async {
    await openCouncilPicker(tester);

    await search(tester, 'narnia');
    expect(find.textContaining('No council matches'), findsOneWidget);
    expect(find.text('Carlow County Council'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No council matches'), findsNothing);
    expect(find.text('Carlow County Council'), findsOneWidget);
    expect(find.text('Wicklow County Council'), findsOneWidget);
  });

  testWidgets('choosing a council from the filtered list selects that council', (tester) async {
    await openCouncilPicker(tester);

    await search(tester, 'wick');
    await tester.tap(find.text('Wicklow County Council'));
    await tester.pumpAndSettle();

    expect(container.read(draftNotifierProvider).council?.name, 'Wicklow County Council');
  });
}
