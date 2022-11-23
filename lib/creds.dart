class Creds {
  final String accessToken;
  final String idToken;
  final String? refreshToken;
  final int expireSeconds;

  Creds({
    required this.accessToken,
    required this.idToken,
    required this.expireSeconds,
    this.refreshToken,
  });
}
