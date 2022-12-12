import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:meta/meta.dart';

// We store the cached decoded token in a separate object so that
// JwtToken can be immutable but still lazilly decode the token

class _JwtTokenCacheState {
  Map<String, dynamic>? decodedToken;

  _JwtTokenCacheState();
}

/// A JWT token based on a raw token string, providing decoded properties, etc.
@immutable
class JwtToken {
  /// The raw JWT token string
  final String rawToken;

  /// The UTC time at which authentication was performed, according to the local computer, if
  /// specified. This is used to estimate clock skew.
  final DateTime? localAuthTime;

  final _cacheState = _JwtTokenCacheState();

  /// Create a JwtToken from a raw JWT token string, and optionally, the known local
  /// computer UTC time at which authentication was performed (used to estimate clock skew).
  JwtToken({required this.rawToken, this.localAuthTime});

  Map<String, dynamic> _createProperties() {
    return JwtDecoder.decode(rawToken);
  }

  Map<String, dynamic> get properties {
    _cacheState.decodedToken = _cacheState.decodedToken ?? _createProperties();
    return _cacheState.decodedToken as Map<String, dynamic>;
  }

  @override
  String toString() {
    return "JwtToken($properties)";
  }

  /// Returns a list of the cognito groups the user is a member of
  List<String> get cognitoGroups {
    return List<String>.from(properties['cognito:groups'] ?? [], growable: false);
  }

  /// Returns the OAUTH2 username. This is normally an opaque ID that the user never sees, but
  /// which is stable across changes to email address, etc.
  String? get userId {
    return properties['username'];
  }

  /// Retrns the user's email address. This is mormally how the user is identified for login.
  String? get email {
    return properties['email'];
  }

  /// Returns the number of seconds since 1/1/1970 UTC at which token expires
  int? get _expEpochSeconds {
    return properties['exp'] as int?;
  }

  /// Returns the UTC time at which the token expires, as measured at the issuer, if specified.
  DateTime? get expTime {
    final secs = _expEpochSeconds;
    final result = (secs == null) ? null : DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
    return result;
  }

  /// Returns the number of seconds since 1/1/1970 UTC at which token was issued
  int? get _iatEpochSeconds {
    return properties['iat'] as int?;
  }

  /// returns the UTC time at which the token was issued, as measured at the issuer, if specified.
  DateTime? get iatTime {
    final secs = _iatEpochSeconds;
    final result = (secs == null) ? null : DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
    return result;
  }

  /// Returns the amount of time the token remains valid after the issue time.
  /// Returns null if either expTime or iatTime is undefined.
  Duration? get expDuration {
    final iat = iatTime;
    final exp = expTime;
    final result = (iat == null || exp == null) ? null : exp.difference(iat);
    return result;
  }

  /// Returns the number of seconds since 1/1/1970 UTC at which authentication was performed
  int? get _authTimeEpochSeconds {
    return properties['auth_time'] as int?;
  }

  /// Returns the time at which authorization was performed (according to the authorizing computer), if specified
  DateTime? get authTime {
    final secs = _authTimeEpochSeconds;
    final result = (secs == null) ? null : DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
    return result;
  }

  /// Returns an estimate of the amount of time the local clock is ahead of (positive) or behind (negative) the token issuer's clock, based on
  /// the difference between localAuthTime (the local time at which authentication happened) and the token's 'auth_time' property.
  /// Returns Duration.zero if localAuthTime or authTime is unknown.
  Duration get localClockSkew {
    final at = authTime;
    final lat = localAuthTime;
    Duration result;
    if (at != null && lat != null) {
      result = lat.difference(at);
    } else {
      result = Duration.zero;
    }
    return result;
  }

  DateTime getIssuerNow() {
    return DateTime.now().toUtc().subtract(localClockSkew);
  }

  /// Returns the age of the token since issuance. The result may be negative due to unadjusted clock skew
  /// between the issuer and the local machine. The result is adjusted with localClockSkew.
  ///
  /// Returns null if iat is not defined.
  Duration? get age {
    final iat = iatTime;
    if (iat == null) {
      return null;
    }
    final result = DateTime.now().toUtc().difference(iat) - localClockSkew;
    return result;
  }

  /// Returns the amount of time remaining before the token expires. The result may be negative due to unadjusted clock skew
  /// between the issuer and the local machine. The result is adjusted with localClockSkew.
  ///
  /// Returns null if exp is not defined.
  Duration? getRemainingDuration({Duration graceDuration = Duration.zero}) {
    final exp = expTime;
    if (exp == null) {
      return null;
    }
    final result = exp.difference(DateTime.now().toUtc()) + localClockSkew;
    return result;
  }
}
