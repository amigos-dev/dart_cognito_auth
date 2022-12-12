import 'access_token.dart';
import "refresh_token.dart";
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
  final RefreshToken? refreshToken;

  /// The number of seconds after authTime at which the access and ID tokens expire.
  final Duration expireDuration;

  const Creds._final({
    required this.accessToken,
    required this.idToken,
    required this.expireDuration,
    this.refreshToken,
  });

  factory Creds({
    required AccessToken accessToken,
    required IdToken idToken,
    required Duration expireDuration,
    RefreshToken? refreshToken,
  }) {
    return Creds._final(
      accessToken: accessToken,
      idToken: idToken,
      expireDuration: expireDuration,
      refreshToken: refreshToken,
    );
  }

  Duration getAccessTokenRemainingDuration({Duration graceDuration = Duration.zero}) {
    final authTime = accessToken.authTime;
    if (authTime == null) {
      return Duration.zero;
    }
    final current = DateTime.now().toUtc();
    final elapsed = current.difference(authTime) + accessToken.localClockSkew;
    var remaining = expireDuration - elapsed - graceDuration;
    remaining = remaining.isNegative ? Duration.zero : remaining;

    return remaining;
  }

  /// Returns true if the amount of remaining time on the access token is
  /// less than an acceptable grace period.
  bool accessTokenIsStale({Duration graceDuration = Duration.zero}) {
    return getAccessTokenRemainingDuration(graceDuration: graceDuration) <= Duration.zero;
  }

  Duration getIdTokenRemainingDuration({Duration graceDuration = Duration.zero}) {
    final authTime = idToken.authTime;
    if (authTime == null) {
      return Duration.zero;
    }
    final current = DateTime.now().toUtc();
    final elapsed = current.difference(authTime) + accessToken.localClockSkew;
    var remaining = expireDuration - elapsed - graceDuration;
    remaining = remaining.isNegative ? Duration.zero : remaining;
    return remaining;
  }

  /// Returns true if the amount of remaining time on the ID token is
  /// less than an acceptable grace period.
  bool idTokenIsStale({Duration graceDuration = Duration.zero}) {
    return getIdTokenRemainingDuration(graceDuration: graceDuration) <= Duration.zero;
  }

  Duration getRefreshTokenRemainingDuration({Duration graceDuration = Duration.zero}) {
    if (refreshToken == null) {
      return Duration.zero;
    }
    return refreshToken!.getRemainingDuration(expireDuration: expireDuration, graceDuration: graceDuration);
  }

  /// Returns true if the amount of remaining time on the refresh token is
  /// less than an acceptable grace period.
  bool refreshTokenIsStale({Duration graceDuration = Duration.zero}) {
    return getRefreshTokenRemainingDuration(graceDuration: graceDuration) <= Duration.zero;
  }

  @override
  String toString() {
    return 'Creds(accessToken="$accessToken", idToken="$idToken", refreshToken="$refreshToken", expireDuration=$expireDuration, '
        'accessTokenRemainingDuration=${getAccessTokenRemainingDuration()})';
  }
}
