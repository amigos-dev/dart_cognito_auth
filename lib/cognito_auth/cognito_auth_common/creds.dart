import 'dart:math';
import 'access_token.dart';
import 'id_token.dart';

class Creds {
  late AccessToken accessToken;
  late IdToken idToken;
  final String? refreshToken;
  final int expireSeconds;
  final DateTime authTime;

  Creds({
    required String rawAccessToken,
    required String rawIdToken,
    required this.expireSeconds,
    this.refreshToken,
    required this.authTime,
  }) {
    accessToken = AccessToken(rawToken: rawAccessToken);
    idToken = IdToken(rawToken: rawIdToken);
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
