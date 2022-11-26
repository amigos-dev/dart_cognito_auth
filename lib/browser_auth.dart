import 'dart:io';
import 'dart:async';
import 'creds.dart';
import 'external_browser.dart' as external_browser;
import 'integrated_browser.dart' as integrated_browser;
import 'util.dart';
import 'authorization_exception.dart';
import 'dart:developer' as developer;

Future<Creds> browserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  String? refreshToken,
  int? port,
  String? callbackUrlScheme,
}) async {
  Creds creds;
  if (refreshToken != null) {
    try {
      developer.log(
          "browserAuthenticate: Attempting to refresh credentials, refresh_token=$refreshToken");
      final tokenUri = cognitoUri.resolve('oauth2/token');
      creds = await refreshCreds(
          tokenUri: tokenUri,
          clientId: clientId,
          clientSecret: clientSecret,
          refreshToken: refreshToken);
      developer.log("browserAuthenticate: Refreshed credentials: creds=$creds");
      return creds;
    } on AuthorizationException catch (e) {
      developer.log(
          "browserAuthenticate: Refresh credentials failed, falling back to browser login: $e");
    }
  }

  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    developer.log("browserAuthenticate: Logging in with external browser");
    creds = await external_browser.externalBrowserAuthenticate(
      cognitoUri: cognitoUri,
      clientId: clientId,
      clientSecret: clientSecret,
      port: port,
      scopes: scopes,
    );
  } else {
    developer.log("browserAuthenticate: Logging in with flutter_web_auth");
    creds = await integrated_browser.integratedBrowserAuthenticate(
        cognitoUri: cognitoUri,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes,
        callbackUrlScheme: callbackUrlScheme);
  }
  developer.log("browserAuthenticate: Browser login complete: creds=$creds");
  return creds;
}
