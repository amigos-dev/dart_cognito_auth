import 'dart:async';
import 'package:flutter/services.dart';

import '../cognito_auth_common/util.dart';
import '../cognito_auth_common/util.dart' as util;
import '../cognito_auth_common/creds.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'dart:developer' as developer;
import '../cognito_auth_common/authorization_exception.dart';

Uri integratedBrowserGetLoginRedirectUri({String? callbackUrlScheme}) {
  callbackUrlScheme = callbackUrlScheme ?? "dev.amigos.cognito-auth";
  final redirectUri = Uri.parse("$callbackUrlScheme://");
  return redirectUri;
}

Future<String> integratedBrowserGetAuthCode({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  Uri? loginRedirectUri,
  String? callbackUrlScheme,
  bool? forceNew,
}) async {
  loginRedirectUri = loginRedirectUri ?? integratedBrowserGetLoginRedirectUri(callbackUrlScheme: callbackUrlScheme);
  callbackUrlScheme = loginRedirectUri.scheme;
  final loginUri = util.getLoginUri(
    cognitoUri: cognitoUri,
    clientId: clientId,
    redirectUri: loginRedirectUri,
    scopes: scopes,
    forceNew: forceNew,
  );
  developer.log('integratedBrowserAuthenticate: Invoking flutter_web_auth, uri=$loginUri, callbackUrlScheme=$callbackUrlScheme');
  String authCode;
  try {
    final resultUriStr = await FlutterWebAuth.authenticate(
      url: loginUri.toString(),
      callbackUrlScheme: callbackUrlScheme,
      preferEphemeral: true,
    );
    developer.log('integratedBrowserAuthenticate: Back from flutter_web_auth, uri=$resultUriStr');
    final resultUri = Uri.parse(resultUriStr);
    authCode = resultUri.queryParameters['code'] as String;
  } on PlatformException catch (e) {
    developer.log('integratedBrowserAuthenticate: flutter_web_auth threw PlatformException: $e');
    throw AuthorizationException("Integrated web login failed", "$e", loginUri);
  }

  return authCode;
}

Future<Creds> integratedBrowserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  String? refreshToken,
  Uri? loginRedirectUri,
  String? callbackUrlScheme,
  bool? forceNew,
}) async {
  loginRedirectUri = loginRedirectUri ?? integratedBrowserGetLoginRedirectUri(callbackUrlScheme: callbackUrlScheme);
  callbackUrlScheme = loginRedirectUri.scheme;
  final tokenUri = cognitoUri.resolve('oauth2/token');
  Creds creds;
  if (refreshToken != null) {
    developer.log("integratedBrowserAuthenticate: Attempting to refresh credentials, refresh_token=$refreshToken");
    try {
      creds = await refreshCreds(tokenUri: tokenUri, clientId: clientId, clientSecret: clientSecret, refreshToken: refreshToken);
      developer.log("integratedBrowserAuthenticate: Refreshed credentials: creds=$creds");
      return creds;
    } on AuthorizationException catch (e) {
      developer.log("integratedBrowserAuthenticate: Refresh credentials failed, falling back to browser login: $e");
      // fall through to regular web auth
    }
  }

  final authCode = await integratedBrowserGetAuthCode(
      cognitoUri: cognitoUri, clientId: clientId, clientSecret: clientSecret, scopes: scopes, loginRedirectUri: loginRedirectUri, forceNew: forceNew);

  creds = await getCredsFromAuthCode(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    authCode: authCode,
    redirectUri: loginRedirectUri,
  );
  return creds;
}
