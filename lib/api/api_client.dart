// Constructor params are named for the public API (httpClient, baseUrl,
// ...), not for the private fields they set (_httpClient, _baseUrl,
// ...) — `this._httpClient` sugar would force callers to use the
// underscored name instead, so this uses a plain initializer list.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/composed_topics.dart';
import '../models/council.dart';
import '../models/lea.dart';
import '../models/message_record.dart';
import '../models/place_match.dart';
import '../models/topic_catalogue.dart';
import 'api_exceptions.dart';

/// One class, every CBAEngine endpoint as a method. Always throws a
/// typed ApiException on failure — never wraps success in a Result type
/// (see the implementation plan's "API client — error handling
/// contract"). Callers needing UI-facing failure *state* (rather than a
/// thrown exception) do that mapping themselves, one layer up.
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required String baseUrl,
    required String? Function() getToken,
    required void Function() onUnauthorized,
  }) : _httpClient = httpClient,
       _baseUrl = baseUrl,
       _getToken = getToken,
       _onUnauthorized = onUnauthorized;

  final http.Client _httpClient;
  final String _baseUrl;
  final String? Function() _getToken;
  final void Function() _onUnauthorized;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  /// The pre-defined topics, and how every email is laid out around the
  /// resident's text (greeting and sign-off).
  Future<TopicCatalogue> getTopics() async {
    final response = await _getPublic(_uri('/topics'));
    return _decode(response, (json) => TopicCatalogue.fromJson(json as Map<String, dynamic>));
  }

  /// The subject and body for the chosen topics. Public (no sign-in): the
  /// resident reads and edits the text before they connect their email.
  /// [variants] are ones already shown (topic id -> variant id): the server
  /// keeps them and picks a random variant only for topics without one.
  Future<ComposedTopics> composeTopics({
    required String localElectoralArea,
    required List<String> topics,
    Map<String, String> variants = const {},
  }) async {
    final response = await _postPublic(
      _uri('/topics/compose'),
      jsonBody: jsonEncode({'local_electoral_area': localElectoralArea, 'topics': topics, 'variants': variants}),
    );
    return _decode(response, (json) => ComposedTopics.fromJson(json as Map<String, dynamic>));
  }

  /// The area(s) a town, village or suburb is in. The text goes in the body, not
  /// the URL, so an address a resident types never reaches an access log.
  Future<PlaceSearchResults> searchPlaces(String query) async {
    final response = await _postPublic(_uri('/places/search'), jsonBody: jsonEncode({'query': query}));
    return _decode(response, (json) => PlaceSearchResults.fromJson(json as Map<String, dynamic>));
  }

  Future<List<Council>> getCouncils() async {
    final response = await _getPublic(_uri('/councils'));
    return _decode(
      response,
      (json) => (json['councils'] as List).map((c) => Council.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<Lea>> getLeasForCouncil(String councilId) async {
    final response = await _getPublic(_uri('/councils/$councilId/leas'));
    return _decode(
      response,
      (json) => (json['leas'] as List).map((l) => Lea.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<Lea>> getLeas() async {
    final response = await _getPublic(_uri('/leas'));
    return _decode(
      response,
      (json) => (json['leas'] as List).map((l) => Lea.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }

  Future<MessageRecord> createMessage({
    required String localElectoralArea,
    required List<String> topics,
    required String subject,
    required String body,
    required String senderName,
    Map<String, String> templateVariants = const {},
  }) async {
    final response = await _postAuthed(
      _uri('/messages'),
      jsonBody: jsonEncode({
        'local_electoral_area': localElectoralArea,
        'topics': topics,
        'template_variants': templateVariants,
        'subject': subject,
        'body': body,
        'sender_name': senderName,
      }),
    );
    return _decode(response, (json) => MessageRecord.fromJson(json as Map<String, dynamic>));
  }

  Future<MessageRecord> getMessage(String id) async {
    final response = await _getAuthed(_uri('/messages/$id'));
    return _decode(response, (json) => MessageRecord.fromJson(json as Map<String, dynamic>));
  }

  Future<MessageRecord> confirmMessage(String id) async {
    final response = await _postAuthed(_uri('/messages/$id/confirm'));
    return _decode(response, (json) => MessageRecord.fromJson(json as Map<String, dynamic>));
  }

  Future<MessageRecord> sendMessage(String id) async {
    final response = await _postAuthed(_uri('/messages/$id/send'));
    return _decode(response, (json) => MessageRecord.fromJson(json as Map<String, dynamic>));
  }

  Future<String> authorizeEmail({
    required String provider,
    required String clientRedirectUri,
    required String clientState,
  }) async {
    final response = await _getPublic(
      _uri('/email/authorize/$provider', {'client_redirect_uri': clientRedirectUri, 'client_state': clientState}),
    );
    return _decode(response, (json) => json['authorization_url'] as String);
  }

  Future<http.Response> _getPublic(Uri uri) async {
    try {
      return await _httpClient.get(uri);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<http.Response> _postPublic(Uri uri, {required String jsonBody}) async {
    try {
      return await _httpClient.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonBody);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<http.Response> _getAuthed(Uri uri) async {
    final token = _requireToken();
    try {
      return await _httpClient.get(uri, headers: {'Authorization': 'Bearer $token'});
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<http.Response> _postAuthed(Uri uri, {String? jsonBody}) async {
    final token = _requireToken();
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    try {
      if (jsonBody != null) {
        headers['Content-Type'] = 'application/json';
        return await _httpClient.post(uri, headers: headers, body: jsonBody);
      }
      return await _httpClient.post(uri, headers: headers);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  String _requireToken() {
    final token = _getToken();
    if (token == null) throw const UnauthenticatedException();
    return token;
  }

  T _decode<T>(http.Response response, T Function(dynamic json) onSuccess) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return onSuccess(decoded);
    }
    if (response.statusCode == 401) {
      _onUnauthorized();
    }
    throw _mapError(response.statusCode, decoded);
  }

  ApiException _mapError(int statusCode, dynamic decoded) {
    final detail = decoded is Map ? decoded['detail'] : null;
    if (detail is List) {
      final errors = detail.map((e) => FieldError.fromJson(e as Map<String, dynamic>)).toList();
      return ValidationException(errors);
    }
    final message = detail is String ? detail : 'Unexpected error (status $statusCode).';
    switch (statusCode) {
      case 400:
        return BadRequestException(message);
      case 401:
        return UnauthorizedException(message);
      case 404:
        return NotFoundException(message);
      case 409:
        return ConflictException(message);
      case 429:
        final availableAt = decoded is Map && decoded['available_at'] is String
            ? DateTime.tryParse(decoded['available_at'] as String)
            : null;
        return RateLimitedException(message, availableAt: availableAt);
      case 503:
        return ServiceUnavailableException(message);
      default:
        return ServerErrorException(message);
    }
  }
}
