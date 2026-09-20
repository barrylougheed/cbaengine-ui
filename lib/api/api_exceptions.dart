import 'package:equatable/equatable.dart';

/// One entry from FastAPI's 422 validation-error shape:
/// {"type", "loc", "msg", "input", ...}. Only `loc`/`msg` are rendered
/// today; the rest is kept for completeness, not currently displayed.
class FieldError extends Equatable {
  const FieldError({required this.loc, required this.msg});

  final List<String> loc;
  final String msg;

  factory FieldError.fromJson(Map<String, dynamic> json) {
    return FieldError(
      loc: (json['loc'] as List<dynamic>).map((e) => e.toString()).toList(),
      msg: json['msg'] as String,
    );
  }

  @override
  List<Object?> get props => [loc, msg];
}

/// Everything ApiClient can throw. The backend returns `{"detail": "..."}`
/// uniformly except FastAPI's own 422 validation errors, which return
/// `{"detail": [...]}` — a list — mapped to ValidationException instead
/// of carrying a plain message.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ValidationException extends ApiException {
  const ValidationException(this.errors) : super('Invalid request.');

  final List<FieldError> errors;
}

class BadRequestException extends ApiException {
  const BadRequestException(super.message);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class RateLimitedException extends ApiException {
  const RateLimitedException(super.message);
}

class ServiceUnavailableException extends ApiException {
  const ServiceUnavailableException(super.message);
}

class ServerErrorException extends ApiException {
  const ServerErrorException(super.message);
}

/// No HTTP response at all — timeout, DNS failure, offline, etc.
class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// Thrown by a call marked `requiresAuth` when there's no token at all —
/// fails fast, without making a network call, same outcome as a 401.
class UnauthenticatedException extends ApiException {
  const UnauthenticatedException() : super('Not connected.');
}
