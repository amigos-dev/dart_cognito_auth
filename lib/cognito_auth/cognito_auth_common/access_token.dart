import 'jwt_token.dart';

class AccessToken extends JwtToken {
  AccessToken({required super.rawToken});

  @override
  String toString() {
    return "AccessToken($properties)";
  }
}
