import 'dart:async';
import 'util.dart';
import 'util.dart' as util;
import 'creds.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'dart:developer' as developer;

Future<Creds> integratedBrowserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  int? port,
  String? callbackUrlScheme,
}) async {
  final redirectUri = Uri.parse("$callbackUrlScheme://on-login");
  final loginUri = util.getLoginUri(
    cognitoUri: cognitoUri,
    clientId: clientId,
    redirectUri: redirectUri,
    scopes: scopes,
  );
  callbackUrlScheme = callbackUrlScheme ?? "dev.amigos.cognito-auth";
  developer.log(
      'Invoking flutter_web_auth, uri=$loginUri, callbackUrlScheme=$callbackUrlScheme');
  final resultUriStr = await FlutterWebAuth.authenticate(
    url: loginUri.toString(),
    callbackUrlScheme: callbackUrlScheme,
    preferEphemeral: true,
  );
  developer.log('Back from flutter_web_auth, uri=$resultUriStr');
  final resultUri = Uri.parse(resultUriStr);
  final String authCode = resultUri.queryParameters['code'] as String;
  final tokenUri = cognitoUri.resolve('oauth2/token');

  final creds = await getCredsFromAuthCode(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    authCode: authCode,
    redirectUri: redirectUri,
  );
  return creds;
}
