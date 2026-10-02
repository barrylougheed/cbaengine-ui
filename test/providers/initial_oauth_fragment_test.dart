import 'package:app/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds the fragment captured at startup until it is consumed', () {
    // The same override main() applies with the fragment it captured.
    final container = ProviderContainer.test(
      overrides: [initialOauthFragmentProvider.overrideWithBuild((ref, notifier) => 'token=abc')],
    );

    expect(container.read(initialOauthFragmentProvider), 'token=abc');

    container.read(initialOauthFragmentProvider.notifier).consume();

    expect(container.read(initialOauthFragmentProvider), isNull);
  });
}
