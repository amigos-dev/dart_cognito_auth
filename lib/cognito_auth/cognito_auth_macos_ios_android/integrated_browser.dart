import 'dart:async';
import 'package:flutter/services.dart';

import '../cognito_auth_common/util.dart';
import '../cognito_auth_common/util.dart' as util;
import '../cognito_auth_common/creds.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'dart:developer' as developer;
import '../cognito_auth_common/authorization_exception.dart';

Future<Creds> integratedBrowserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  String? refreshToken,
  int? port,
  String? callbackUrlScheme,
}) async {
  final tokenUri = cognitoUri.resolve('oauth2/token');
  Creds creds;
  if (refreshToken != null) {
    developer.log(
        "integratedBrowserAuthenticate: Attempting to refresh credentials, refresh_token=$refreshToken");
    try {
      creds = await refreshCreds(
          tokenUri: tokenUri,
          clientId: clientId,
          clientSecret: clientSecret,
          refreshToken: refreshToken);
      developer.log(
          "integratedBrowserAuthenticate: Refreshed credentials: creds=$creds");
      return creds;
    } on AuthorizationException catch (e) {
      developer.log(
          "integratedBrowserAuthenticate: Refresh credentials failed, falling back to browser login: $e");
      // fall through to regular web auth
    }
  }

  callbackUrlScheme = callbackUrlScheme ?? "dev.amigos.cognito-auth";
  final redirectUri = Uri.parse("$callbackUrlScheme://");
  final loginUri = util.getLoginUri(
    cognitoUri: cognitoUri,
    clientId: clientId,
    redirectUri: redirectUri,
    scopes: scopes,
  );
  developer.log(
      'integratedBrowserAuthenticate: Invoking flutter_web_auth, uri=$loginUri, callbackUrlScheme=$callbackUrlScheme');
  String authCode;
  try {
    final resultUriStr = await FlutterWebAuth.authenticate(
      url: loginUri.toString(),
      callbackUrlScheme: callbackUrlScheme,
      preferEphemeral: true,
    );
    developer.log(
        'integratedBrowserAuthenticate: Back from flutter_web_auth, uri=$resultUriStr');
    final resultUri = Uri.parse(resultUriStr);
    authCode = resultUri.queryParameters['code'] as String;
  } on PlatformException catch (e) {
    developer.log(
        'integratedBrowserAuthenticate: flutter_web_auth threw PlatformException: $e');
    throw AuthorizationException("Integrated web login failed", "$e", loginUri);
  }

  creds = await getCredsFromAuthCode(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    authCode: authCode,
    redirectUri: redirectUri,
  );
  return creds;
}
