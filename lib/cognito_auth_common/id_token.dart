import 'jwt_token.dart';
import 'package:meta/meta.dart';

@immutable
class IdToken extends JwtToken {
  IdToken({required super.rawToken, super.localAuthTime});

  @override
  String toString() {
    return "IdToken($properties)";
  }
}
