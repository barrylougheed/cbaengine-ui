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
  // name -> (areas, councillors)
  const counts = {
    'Carlow County Council': (3, 18),
    'Dublin City Council': (11, 63),
    'Dún Laoghaire-Rathdown County Council': (6, 40),
    'Fingal County Council': (7, 40),
    'Galway City Council': (3, 18),
    'Galway County Council': (5, 39),
    'Wicklow County Council': (6, 32),
  };
  final names = counts.keys.toList();

  late ProviderContainer container;

  http.Response jsonResponse(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/councils') {
      return jsonResponse({
        'councils': [
          for (final entry in counts.entries)
            {
              'id': entry.key.toLowerCase().replaceAll(' ', '-'),
              'name': entry.key,
              'area_count': entry.value.$1,
              'councillor_count': entry.value.$2,
            },
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

  testWidgets('says how many councils and councillors there are in all', (tester) async {
    await openCouncilPicker(tester);

    // 18 + 63 + 40 + 40 + 18 + 39 + 32 councillors in 7 councils.
    expect(find.text('7 councils · 250 councillors'), findsOneWidget);
  });

  testWidgets('each council says how many areas and councillors it has', (tester) async {
    await openCouncilPicker(tester);

    expect(find.text('3 areas · 18 councillors'), findsNWidgets(2)); // Carlow and Galway City
    expect(find.text('7 areas · 40 councillors'), findsOneWidget); // Fingal
    expect(find.text('11 areas · 63 councillors'), findsOneWidget); // Dublin City
  });

  testWidgets('a search narrows the total to what is shown', (tester) async {
    await openCouncilPicker(tester);

    await search(tester, 'galway');

    expect(find.text('2 councils · 57 councillors'), findsOneWidget);
  });
}
