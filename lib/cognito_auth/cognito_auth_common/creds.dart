import 'dart:math';
import 'access_token.dart';
import 'id_token.dart';
import 'package:meta/meta.dart';

/// Immutable Oauth2 credentials
@immutable
class Creds {
  /// OAuth2 JWT ID token
  final AccessToken accessToken;

  /// OAuth2 JWT ID token
  final IdToken idToken;

  /// Optional opaque Oauth2 refresh token. Expiration time indeterminate.
  final String? refreshToken;

  /// The number of seconds after authTime at which the access and ID tokens expire.
  final int expireSeconds;

  /// The UTC time (as determined locally) at which creds were generated
  final DateTime authTime;

  const Creds._final({
    required this.accessToken,
    required this.idToken,
    required this.expireSeconds,
    this.refreshToken,
    required this.authTime,
  });

  factory Creds({
    required String rawAccessToken,
    required String rawIdToken,
    required int expireSeconds,
    String? refreshToken,
    required DateTime authTime,
  }) {
    final accessToken = AccessToken(rawToken: rawAccessToken);
    final idToken = IdToken(rawToken: rawIdToken);
    return Creds._final(
      accessToken: accessToken,
      idToken: idToken,
      expireSeconds: expireSeconds,
      refreshToken: refreshToken,
      authTime: authTime,
    );
  }

  double getRemainingSeconds() {
    final currentMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final authTimeMs = authTime.toUtc().millisecondsSinceEpoch;
    final elapsedMs = max(currentMs - authTimeMs, 0);
    final remainingMs = max(expireSeconds * 1000 - elapsedMs, 0);
    return remainingMs / 1000.0;
  }

  @override
  String toString() {
    return 'Creds(accessToken="$accessToken", idToken="$idToken", refreshToken="$refreshToken", expireSeconds=$expireSeconds, remainingSeconds=${getRemainingSeconds()})';
  }
}
