import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import '../cognito_auth_common/util.dart';
import '../cognito_auth_common/util.dart' as util;
import '../cognito_auth_common/authorization_exception.dart';
import '../cognito_auth_common/creds.dart';
import 'dart:developer' as developer;

Future<void> externalBrowserLaunchUri(Uri uri) async {
  String launcher;
  bool runInShell = false;
  List<String> cmdArgs = [uri.toString()];
  if (Platform.isLinux) {
    launcher = 'xdg-open';
  } else if (Platform.isMacOS) {
    launcher = 'open';
  } else if (Platform.isWindows) {
    launcher = 'rundll32.exe';
    cmdArgs = ["url.dll,FileProtocolHandler", uri.toString()];
    //runInShell = true;
  } else {
    throw "Don't know how to launch URL on platform ${Platform.operatingSystem}";
  }

  developer.log("launching browser with prog='$launcher', args=$cmdArgs");
  final browserLaunch = await Process.run(
    launcher,
    cmdArgs,
    runInShell: runInShell,
  );
  if (browserLaunch.exitCode != 0) {
    developer.log(browserLaunch.stdout);
    developer.log(browserLaunch.stderr);
    throw "Could not launch browser with prog='$launcher', args=$cmdArgs: exit code ${browserLaunch.exitCode}";
  }
  developer.log('Browser launched');
}

class ExternalBrowserAuthCodeGetter {
  final _completer = Completer<String>();
  final Uri cognitoUri;
  final String clientId;
  final int port;
  late Uri loginRedirectUri;
  late List<String>? scopes;
  late bool forceNew;

  ExternalBrowserAuthCodeGetter({required this.cognitoUri, required this.clientId, this.port = 8501, List<String>? scopes, bool? forceNew}) {
    loginRedirectUri = Uri.parse('http://localhost:$port/');
    this.scopes = scopes == null ? null : List<String>.from(scopes);
    this.forceNew = forceNew ?? false;
  }

  Uri getLoginUri() {
    return util.getLoginUri(
      cognitoUri: cognitoUri,
      clientId: clientId,
      redirectUri: loginRedirectUri,
      scopes: scopes,
      forceNew: forceNew,
    );
  }

  reqLog(String message, bool isError) {
    developer.log("${isError ? '[ERROR]' : ''}$message");
  }

  Future<String> run() async {
    // final staticHandler = shelf_static.createStaticHandler(
    //   'public',
    //   defaultDocument: 'index.html',
    // );

    final router = shelf_router.Router()..get('/', mainHandler);
    final cascade = Cascade()
        // .add(staticHandler)
        .add(router);
    final server = await shelf_io.serve(
      logRequests(logger: reqLog).addHandler(cascade.handler),
      '127.0.0.1', // Do not allow external connections
      port,
    );

    developer.log('Serving at http://${server.address.host}:${server.port}/');

    final loginUri = getLoginUri();

    await externalBrowserLaunchUri(loginUri);

    final authCode = await _completer.future;

    developer.log("auth-getter future completed; shutting down http server");

    await server.close();

    return authCode;
  }

  static const _jsonHeaders = {
    'content-type': 'application/json',
  };

  Response mainHandler(Request request) {
    try {
      final params = request.url.queryParameters;
      if (params.containsKey('error')) {
        final description = params['error_description'];
        final uriString = params['error_uri'];
        final uri = uriString == null ? null : Uri.parse(uriString);
        throw AuthorizationException(params['error']!, description, uri);
      } else if (params.containsKey('code')) {
        final String authCode = params['code'] as String;
        final result = Response(
          200,
          headers: {
            ..._jsonHeaders,
            'Cache-Control': 'no-store',
          },
          body: jsonEncode(
            {
              'code': authCode,
            },
          ),
        );
        developer.log("completing auth-getter future");
        _completer.complete(authCode);
        return result;
        /*
      } else if (params.containsKey("action")) {
        final action = params['action'];
        if (action == "logout") {
          final result = Response(
            200,
            headers: {
              ..._jsonHeaders,
              'Cache-Control': 'no-store',
            },
            body: _jsonEncode(
              {
                'action': 'logout',
              },
            ),
          );
          return result;
        } else {
          final result = Response(
            501,
            headers: {
              ..._jsonHeaders,
              'Cache-Control': 'no-store',
            },
            body: _jsonEncode(
              {
                'error': 'Unrecognized action',
                'action': action,
              },
            ),
          );
          return result;
        }
        */
      } else {
        final redirectUri = getLoginUri();
        final result = Response(
          200,
          headers: {
            ..._jsonHeaders,
            'Cache-Control': 'no-store',
          },
          body: jsonEncode(
            {
              'redirect_uri': redirectUri.toString(),
              'query_parameters': params,
            },
          ),
        );

        return result;
      }
    } catch (e) {
      _completer.completeError(e);
      rethrow;
    }
  }
}

Future<Creds> externalBrowserAuthenticate({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  String? refreshToken,
  List<String>? scopes,
  int? port,
  bool? forceNew,
}) async {
  final tokenUri = cognitoUri.resolve('oauth2/token');
  Creds creds;
  if (refreshToken != null) {
    try {
      creds = await refreshCreds(tokenUri: tokenUri, clientId: clientId, clientSecret: clientSecret, refreshToken: refreshToken);
      return creds;
    } on AuthorizationException {
      // fall through to regular web auth
    }
  }

  final authCodeGetter = ExternalBrowserAuthCodeGetter(
    cognitoUri: cognitoUri,
    clientId: clientId,
    scopes: scopes,
    port: port ?? 8501,
    forceNew: forceNew,
  );
  final authCode = await authCodeGetter.run();
  creds = await getCredsFromAuthCode(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    authCode: authCode,
    redirectUri: authCodeGetter.loginRedirectUri,
  );
  return creds;
}