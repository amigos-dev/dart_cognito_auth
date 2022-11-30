import 'package:jwt_decoder/jwt_decoder.dart';

class JwtToken {
  final String rawToken;
  Map<String, dynamic>? _decodedToken;
  final double? localAuthTimeEpochSeconds;

  JwtToken({required this.rawToken, this.localAuthTimeEpochSeconds});

  Map<String, dynamic> _createProperties() {
    return JwtDecoder.decode(rawToken);
  }

  Map<String, dynamic> get properties {
    _decodedToken = _decodedToken ?? _createProperties();
    return _decodedToken as Map<String, dynamic>;
  }

  @override
  String toString() {
    return "JwtToken($properties)";
  }

  // Returns a list of the cognito groups the user is a member of
  List<String> get cognitoGroups {
    return properties['cognito:groups'] ?? [];
  }

  // Returns the OAUTH2 username. This is normally an opaque ID that the user never sees, but
  // which is stable across changes to email address, etc.
  String? get userId {
    return properties['username'];
  }

  // Retrns the user's email address. This is mormally how the user is identified for login.
  String? get email {
    return properties['email'];
  }

  // Returns the number of seconds since 1/1/1970 UTC at which token expires
  int? get expEpochSeconds {
    return properties['exp'] as int?;
  }

  // Returns the number of seconds since 1/1/1970 UTC at which token was issued
  int? get iatEpochSeconds {
    return properties['iat'] as int?;
  }

  // Returns the number of seconds since 1/1/1970 UTC at which authentication was performed
  int? get authTimeEpochSeconds {
    return properties['auth_time'] as int?;
  }
}
