import '../cognito_auth_common/cognito_auth_common.dart';
import "flutter_secure_store.dart";

class FlutterCognitoAuthorizer extends CognitoAuthorizer {
  FlutterCognitoAuthorizer._bare({
    required super.authConfig,
    super.initialRefreshToken,
    required super.loginCallbackUri,
    super.refreshTokenStore,
  });

  factory FlutterCognitoAuthorizer({
    required AuthConfig authConfig,
    RefreshToken? initialRefreshToken,
    required Uri loginCallbackUri,
  }) {
    final refreshTokenStore = FlutterSecureStore();
    final result = FlutterCognitoAuthorizer._bare(
      authConfig: authConfig,
      initialRefreshToken: initialRefreshToken,
      loginCallbackUri: loginCallbackUri,
      refreshTokenStore: refreshTokenStore,
    );
    return result;
  }
}
