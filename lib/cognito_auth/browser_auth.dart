import 'dart:io';
import 'dart:async';
import 'cognito_auth_common/creds.dart';
import 'cognito_auth_desktop_cli/external_browser.dart' as external_browser;
import 'cognito_auth_macos_ios_android/integrated_browser.dart' as integrated_browser;
import 'cognito_auth_common/util.dart';
import 'cognito_auth_common/authorization_exception.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;

Future<Creds> browserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  String? refreshToken,
  int? port,
  Uri? callbackUri,
  bool? forceNew,
}) async {
  Creds creds;
  if (refreshToken != null) {
    try {
      developer.log("browserAuthenticate: Attempting to refresh credentials, refresh_token=$refreshToken");
      final tokenUri = cognitoUri.resolve('oauth2/token');
      creds = await refreshCreds(tokenUri: tokenUri, clientId: clientId, clientSecret: clientSecret, refreshToken: refreshToken);
      developer.log("browserAuthenticate: Refreshed credentials: creds=$creds");
      return creds;
    } on AuthorizationException catch (e) {
      developer.log("browserAuthenticate: Refresh credentials failed, falling back to browser login: $e");
    }
  }

  if (kIsWeb) {
    throw AuthorizationException("Not supported on Web platform");
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    // NOTE: macOS should be using integrated browser strategy, but
    //       flutter_web_auth throws an exception in swift, so for now
    //       we will launch an external browser.
    developer.log("browserAuthenticate: Logging in with external browser");
    creds = await external_browser.externalBrowserAuthenticate(
      cognitoUri: cognitoUri,
      clientId: clientId,
      clientSecret: clientSecret,
      port: port,
      scopes: scopes,
      forceNew: forceNew,
    );
  } else {
    developer.log("browserAuthenticate: Logging in with integrated browser auth");

    final callbackUriScheme = (callbackUri == null) ? null : callbackUri.scheme;

    creds = await integrated_browser.integratedBrowserAuthenticate(
        cognitoUri: cognitoUri,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes,
        callbackUrlScheme: callbackUriScheme,
        forceNew: forceNew);
  }
  developer.log("browserAuthenticate: Browser login complete: creds=$creds");
  return creds;
}
