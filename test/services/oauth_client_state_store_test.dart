import 'package:app/models/oauth_result.dart';
import 'package:app/services/oauth_client_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OAuthClientStateStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OAuthClientStateStore(await SharedPreferences.getInstance());
  });

  OAuthSuccess success({String? clientState}) =>
      OAuthSuccess(token: 'token', email: 'resident@example.com', provider: 'google', clientState: clientState);

  test('create makes a URL-safe value the backend accepts, different each time', () async {
    final first = await store.create();
    final second = await store.create();

    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(second, isNot(first));
  });

  test('a connection carrying the value this app made up is accepted', () async {
    final clientState = await store.create();
    final returned = success(clientState: clientState);

    expect(await store.verify(returned), returned);
  });

  test("a link carrying someone else's token, with no value at all, is refused", () async {
    await store.create();

    final result = await store.verify(success());

    expect(result, isA<OAuthFailure>());
    expect((result as OAuthFailure).errorDescription, OAuthClientStateStore.notStartedHereMessage);
  });

  test('a connection with a different value is refused', () async {
    await store.create();

    expect(await store.verify(success(clientState: 'someone-elses-value')), isA<OAuthFailure>());
  });

  test('a connection is refused when this app never started one', () async {
    expect(await store.verify(success(clientState: 'anything')), isA<OAuthFailure>());
  });

  test('the value is single-use, so the same return cannot be accepted twice', () async {
    final clientState = await store.create();

    await store.verify(success(clientState: clientState));

    expect(await store.verify(success(clientState: clientState)), isA<OAuthFailure>());
  });

  test("a provider's own failure is passed through unchanged", () async {
    await store.create();
    const failure = OAuthFailure(errorCode: 'access_denied', errorDescription: 'Declined.');

    expect(await store.verify(failure), failure);
  });
}
