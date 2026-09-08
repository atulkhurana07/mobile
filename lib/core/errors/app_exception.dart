class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  AppException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class UnauthorizedException extends AppException {
  UnauthorizedException({String message = 'Session expired. Please log in again.'})
      : super(message, statusCode: 401);
}

class ForbiddenException extends AppException {
  ForbiddenException({String message = 'You are not authorized to perform this action.'})
      : super(message, statusCode: 403);
}

class NotFoundException extends AppException {
  NotFoundException({String message = 'Requested resource not found.'})
      : super(message, statusCode: 404);
}

class ValidationException extends AppException {
  ValidationException(String message, {dynamic details})
      : super(message, statusCode: 422, details: details);
}
