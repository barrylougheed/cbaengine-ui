// Boot smoke test — real per-screen/notifier tests arrive alongside
// their implementations per the build order (TDD for the logic layer).

import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/app.dart';
import 'package:app/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('the app boots to the home screen', (WidgetTester tester) async {
    final mockHttpClient = MockClient((request) async {
      return http.Response(jsonEncode({'councils': <Object>[]}), 200);
    });
    final apiClient = ApiClient(
      httpClient: mockHttpClient,
      baseUrl: 'http://localhost:8000',
      getToken: () => null,
      onUnauthorized: () {},
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
        child: const CbaEngineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.text('Craft an email'), findsOneWidget);
    expect(find.text('CBAEngine'), findsOneWidget);
    expect(find.text('Privacy notice'), findsOneWidget);
  });

  testWidgets('the browser tab is titled for the service, not just its name', (WidgetTester tester) async {
    // On the web Flutter sets the tab title from MaterialApp.title at run time,
    // overwriting whatever web/index.html says, so the two must agree.
    final apiClient = ApiClient(
      httpClient: MockClient((request) async => http.Response(jsonEncode({'councils': <Object>[]}), 200)),
      baseUrl: 'http://localhost:8000',
      getToken: () => null,
      onUnauthorized: () {},
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
        child: const CbaEngineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'CBAEngine - email your local councillors');
  });
}
