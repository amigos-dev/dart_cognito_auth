import 'dart:io';
import 'dart:async';
import 'creds.dart';
import 'external_browser.dart' as external_browser;
import 'integrated_browser.dart' as integrated_browser;

Future<Creds> browserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  int? port,
  String? callbackUrlScheme,
}) async {
  Creds creds;
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    creds = await external_browser.externalBrowserAuthenticate(
      cognitoUri: cognitoUri,
      clientId: clientId,
      clientSecret: clientSecret,
      port: port,
      scopes: scopes,
    );
  } else {
    creds = await integrated_browser.integratedBrowserAuthenticate(
        cognitoUri: cognitoUri,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes,
        callbackUrlScheme: callbackUrlScheme);
  }
  return creds;
}
