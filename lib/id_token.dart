import 'jwt_token.dart';

class IdToken extends JwtToken {
  IdToken({required super.rawToken});

  @override
  String toString() {
    return "IdToken($properties)";
  }
}
