import 'jwt_token.dart';
import 'package:meta/meta.dart';

@immutable
class AccessToken extends JwtToken {
  AccessToken({required super.rawToken, super.localAuthTime});

  @override
  String toString() {
    return "AccessToken($properties)";
  }
}
