import 'dart:math';

class Creds {
  final String accessToken;
  final String idToken;
  final String? refreshToken;
  final int expireSeconds;
  final DateTime authTime;

  Creds({
    required this.accessToken,
    required this.idToken,
    required this.expireSeconds,
    this.refreshToken,
    required this.authTime,
  });

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
