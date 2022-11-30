// import 'dart:io';
import 'dart:async';
// import 'package:shelf/shelf.dart';
// import 'package:shelf/shelf_io.dart' as shelf_io;
// import 'package:shelf_router/shelf_router.dart' as shelf_router;
// import '../cognito_auth_desktop/desktop_util.dart';
import '../cognito_auth_common/util.dart';
import '../cognito_auth_common/util.dart' as util;
import '../cognito_auth_common/authorization_exception.dart';
import '../cognito_auth_common/creds.dart';
import "package:universal_html/html.dart" as html;

class SameBrowserAuthenticator {
  final _completer = Completer<Creds>();
  final Uri cognitoUri;
  final String clientId;
  String? clientSecret;
  final Uri loginRedirectUri;
  late List<String>? scopes;

  SameBrowserAuthenticator({
    required this.cognitoUri,
    required this.clientId,
    this.clientSecret,
    required this.loginRedirectUri,
    List<String>? scopes,
  }) {
    this.scopes = scopes == null ? null : List<String>.from(scopes);
  }

  Future<Creds> getCredsFromCallback(Uri uri) async {
    final authCode = uri.queryParameters['code'] as String;
    final tokenUri = cognitoUri.resolve('oauth2/token');
    final creds = await getCredsFromAuthCode(
      tokenUri: tokenUri,
      clientId: clientId,
      clientSecret: clientSecret,
      authCode: authCode,
      redirectUri: loginRedirectUri,
    );
    return creds;
  }

  void onCallback(Uri uri) {
    getCredsFromCallback(uri)
        .then((creds) => _completer.complete(creds))
        .onError((error, stackTrace) => _completer.completeError(
            error ?? 'Login callback error', stackTrace));
  }

  Future<Creds> getResult() async {
    throw 'not implemented';
  }
}

Future<Creds> sameBrowserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  String? refreshToken,
  List<String>? scopes,
  Uri? loginRedirectUri,
}) async {
  final tokenUri = cognitoUri.resolve('oauth2/token');
  Creds creds;

  if (refreshToken != null) {
    try {
      creds = await refreshCreds(
          tokenUri: tokenUri,
          clientId: clientId,
          clientSecret: clientSecret,
          refreshToken: refreshToken);
      return creds;
    } on AuthorizationException {
      // fall through to regular web auth
    }
  }

  loginRedirectUri = loginRedirectUri ?? Uri.base.resolve('on-login');

  final loginUri = util.getLoginUri(
    cognitoUri: cognitoUri,
    clientId: clientId,
    redirectUri: loginRedirectUri,
    scopes: scopes,
  );

  html.window.open(loginUri.toString(), "_self");
  throw 'not implemented';
}
