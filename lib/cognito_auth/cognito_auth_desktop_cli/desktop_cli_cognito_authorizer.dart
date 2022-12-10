import 'dart:async';
import "dart:io";
import "package:path/path.dart" as path;
//import 'dart:developer' as developer;
import 'package:cognito_auth/cognito_auth/cognito_auth_common/async_key_value_store.dart';

import '../cognito_auth_common/cognito_auth_common.dart';
import "external_browser.dart";
import "json_file_store.dart";

const defaultDefaultAuthCallbackPortStr = '8501';
const defaultAuthCallbackPortStr = String.fromEnvironment('AUTH_CALLBACK_PORT', defaultValue: defaultDefaultAuthCallbackPortStr);
final int defaultAuthCallbackPort = int.parse(defaultAuthCallbackPortStr);

String _getHomeDirectory() {
  String home;
  if (Platform.isMacOS || Platform.isLinux) {
    home = Platform.environment['HOME']!;
  } else if (Platform.isWindows) {
    home = Platform.environment['UserProfile']!;
  } else {
    throw "No Home directory on this platform";
  }
  return home;
}

class DesktopCliCognitoAuthorizer extends CognitoAuthorizer {
  DesktopCliCognitoAuthorizer._bare({
    required super.authConfig,
    super.initialRefreshToken,
    required super.loginCallbackUri,
    super.refreshTokenStore,
  });

  factory DesktopCliCognitoAuthorizer({
    required AuthConfig authConfig,
    String? initialRefreshToken,
    int? port,
    AsyncKeyValueStore? refreshTokenStore,
    String? refreshTokenStorePathname,
  }) {
    port = port ?? defaultAuthCallbackPort;
    final callbackUri = Uri.parse("http://localhost:$port/");

    if (refreshTokenStore == null && authConfig.usePersistentRefreshToken) {
      var refreshTokenStoreDir = Platform.environment['TOKEN_STORE_DIR'];
      if (refreshTokenStoreDir == null || refreshTokenStoreDir == '') {
        refreshTokenStoreDir = const bool.hasEnvironment("TOKEN_STORE_DIR") ? const String.fromEnvironment("TOKEN_STORE_DIR") : null;
      }
      if (refreshTokenStoreDir == null || refreshTokenStoreDir == '') {
        refreshTokenStoreDir = (refreshTokenStorePathname != null) ? '.' : path.join(_getHomeDirectory(), '.private', 'oauth_refresh_tokens');
      }

      refreshTokenStorePathname = refreshTokenStorePathname ?? Platform.environment['TOKEN_STORE_FILE'];
      if (refreshTokenStorePathname == null || refreshTokenStorePathname == '') {
        refreshTokenStorePathname = const bool.hasEnvironment("TOKEN_STORE_FILE") ? const String.fromEnvironment("TOKEN_STORE_FILE") : null;
      }
      if (refreshTokenStorePathname == null || refreshTokenStorePathname == '') {
        refreshTokenStorePathname = "tokens-${authConfig.clientId}.json";
      }
      final fullPath = path.absolute(refreshTokenStoreDir, refreshTokenStorePathname);
      refreshTokenStore = JsonFileStore(pathname: fullPath);
    }

    final result = DesktopCliCognitoAuthorizer._bare(
        authConfig: authConfig, initialRefreshToken: initialRefreshToken, loginCallbackUri: callbackUri, refreshTokenStore: refreshTokenStore);
    return result;
  }

  Future<Creds> login({
    bool? allowRefresh,
    bool? forceNew,
  }) async {
    forceNew = forceNew ?? false;
    allowRefresh = !forceNew && (allowRefresh ?? true);
    if (forceNew) {
      await asyncClear();
    }
    Creds result;
    if (allowRefresh) {
      try {
        result = await refresh();
        return result;
      } on AuthorizationException {
        // fall through to regular login
      }
    }
    final authCode = await externalBrowserGetAuthCode(
      cognitoUri: cognitoUri,
      clientId: clientId,
      clientSecret: clientSecret,
      scopes: scopes,
      port: loginCallbackUri.port,
      forceNew: forceNew,
    );
    result = await fromAuthCode(authCode);
    return result;
  }

  Future<void> logout() async {
    await asyncClear();
    await externalBrowserLogout(cognitoUri: cognitoUri, clientId: clientId, port: logoutCallbackUri.port);
  }
}
