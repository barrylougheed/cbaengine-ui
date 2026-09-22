// Boot smoke test — real per-screen/notifier tests arrive alongside
// their implementations per the build order (TDD for the logic layer).

import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/app.dart';
import 'package:app/providers/core_providers.dart';
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
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
        child: const CbaEngineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.text('Contact your councillors'), findsOneWidget);
    expect(find.text('CBAEngine'), findsOneWidget);
  });
}
