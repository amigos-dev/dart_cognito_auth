class AuthorizationException implements Exception {
  final String error;
  final String? description;
  final Uri? uri;

  AuthorizationException(this.error, [this.description, this.uri]);

  /// Provides a string description of the AuthorizationException.
  @override
  String toString() {
    var header = 'OAuth authorization error ($error)';
    if (description != null) {
      header = '$header: $description';
    } else if (uri != null) {
      header = '$header: $uri';
    }
    return '$header.';
  }
}
