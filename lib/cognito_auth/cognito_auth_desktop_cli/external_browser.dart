import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import '../cognito_auth_common/util.dart';
import '../cognito_auth_common/util.dart' as util;
import '../cognito_auth_common/authorization_exception.dart';
import '../cognito_auth_common/creds.dart';
import 'package:mutex/mutex.dart';
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

// Only one server can be running on a port, so we create a mutex for each port that is ever used
final Map<int, Mutex> _portMutexes = {};
Mutex _portMutex(int port) {
  var result = _portMutexes[port];
  if (result == null) {
    result = Mutex();
    _portMutexes[port] = result;
  }
  return result;
}

class ExternalBrowserCallbackFlow {
  final _completer = Completer<Uri>();
  final Uri launchUri;
  final int port;
  late Mutex m;

  ExternalBrowserCallbackFlow({required this.launchUri, this.port = 8501}) {
    m = _portMutex(port);
  }

  void reqLog(String message, bool isError) {
    developer.log("${isError ? '[ERROR]' : ''}$message");
  }

  Future<Uri> runFlow() async {
    final result = await m.protect<Uri>(() async {
      final router = shelf_router.Router()..get('/', mainHandler);
      final cascade = Cascade()
          // .add(staticHandler)
          .add(router);
      Uri resultUri;
      final server = await shelf_io.serve(
        logRequests(logger: reqLog).addHandler(cascade.handler),
        '127.0.0.1', // Do not allow external connections
        port,
      );
      try {
        developer.log('Serving at http://${server.address.host}:${server.port}/');

        await externalBrowserLaunchUri(launchUri);

        resultUri = await _completer.future;
      } finally {
        await server.close();
      }

      return resultUri;
    });
    return result;
  }

  String generateResponseMessage(Uri requestUri) {
    return "The authentication operation is complete. You may close this browser and return to the application to proceed.";
  }

  Map<String, dynamic> generateResponseObject(Uri requestUri) {
    return {
      "message": generateResponseMessage(requestUri),
      "args": requestUri.queryParameters,
    };
  }

  Response generateResponse(Uri requestUri) {
    final result = Response(
      200,
      headers: {
        'content-type': 'application/json',
        'Cache-Control': 'no-store',
      },
      body: jsonEncode(generateResponseObject(requestUri)),
    );
    return result;
  }

  Response mainHandler(Request request) {
    final uri = request.url;
    try {
      developer.log("completing ExternalBrowserCallbackFlow future, uri=$uri");
      _completer.complete(uri);
    } catch (e) {
      _completer.completeError(e);
      rethrow;
    }
    return generateResponse(uri);
  }
}

class ExternalBrowserAuthCodeFlow extends ExternalBrowserCallbackFlow {
  final Uri cognitoUri;
  final String clientId;
  final Uri loginRedirectUri;
  late List<String>? scopes;
  late bool forceNew;

  ExternalBrowserAuthCodeFlow._bare(
      {required this.loginRedirectUri,
      required this.cognitoUri,
      required this.clientId,
      super.port,
      List<String>? scopes,
      bool? forceNew,
      required super.launchUri}) {
    this.scopes = scopes == null ? null : List<String>.from(scopes);
    this.forceNew = forceNew ?? false;
  }

  factory ExternalBrowserAuthCodeFlow({
    required Uri cognitoUri,
    required String clientId,
    int port = 8501,
    List<String>? scopes,
    bool? forceNew,
  }) {
    final loginRedirectUri = Uri.parse('http://localhost:$port/');
    final launchUri = util.getLoginUri(
      cognitoUri: cognitoUri,
      clientId: clientId,
      redirectUri: loginRedirectUri,
      scopes: scopes,
      forceNew: forceNew,
    );
    final flow = ExternalBrowserAuthCodeFlow._bare(
        loginRedirectUri: loginRedirectUri,
        cognitoUri: cognitoUri,
        clientId: clientId,
        port: port,
        scopes: scopes,
        forceNew: forceNew,
        launchUri: launchUri);
    return flow;
  }

  @override
  String generateResponseMessage(Uri requestUri) {
    final params = requestUri.queryParameters;
    if (params.containsKey('error') || !params.containsKey('code')) {
      return "Authorization code login failed. You may close this browser and return to the application to proceed.";
    }
    return "Authorization code login succeeded. You may close this browser and return to the application to proceed.";
  }

  Future<String> run() async {
    final uri = await runFlow();
    final params = uri.queryParameters;
    String authCode;
    if (params.containsKey('error')) {
      final description = params['error_description'];
      final uriString = params['error_uri'];
      final uri = uriString == null ? null : Uri.parse(uriString);
      throw AuthorizationException(params['error']!, description, uri);
    } else if (params.containsKey('code')) {
      authCode = params['code'] as String;
    } else {
      throw AuthorizationException("Invalid callback URL", "Invalid Callback URL", uri);
    }

    return authCode;
  }
}

class ExternalBrowserLogoutFlow extends ExternalBrowserCallbackFlow {
  final Uri cognitoUri;
  final String clientId;
  final Uri logoutRedirectUri;

  ExternalBrowserLogoutFlow._bare(
      {required this.logoutRedirectUri, required this.cognitoUri, required this.clientId, super.port, required super.launchUri});

  factory ExternalBrowserLogoutFlow({
    required Uri cognitoUri,
    required String clientId,
    int port = 8501,
  }) {
    final logoutRedirectUri = Uri.parse('http://localhost:$port/?action=logout');
    final launchUri = util.getLogoutUri(
      cognitoUri: cognitoUri,
      clientId: clientId,
      redirectUri: logoutRedirectUri,
    );
    final flow = ExternalBrowserLogoutFlow._bare(
        logoutRedirectUri: logoutRedirectUri, cognitoUri: cognitoUri, clientId: clientId, port: port, launchUri: launchUri);
    return flow;
  }

  @override
  String generateResponseMessage(Uri requestUri) {
    final params = requestUri.queryParameters;
    if (params.containsKey('error') || params['action'] != 'logout') {
      return "OAUTH2 logout failed. You may close this browser and return to the application to proceed.";
    }
    return "OAUTH2 logout succeeded. You may close this browser and return to the application to proceed.";
  }

  Future<void> run() async {
    final uri = await runFlow();
    final params = uri.queryParameters;
    if (params.containsKey('error')) {
      final description = params['error_description'];
      final uriString = params['error_uri'];
      final uri = uriString == null ? null : Uri.parse(uriString);
      throw AuthorizationException(params['error']!, description, uri);
    } else if (params['action'] != 'logout') {
      throw AuthorizationException("Invalid callback URL", "Invalid Callback URL", uri);
    }
  }
}

Future<String> externalBrowserGetAuthCode({
  required Uri cognitoUri,
  required String clientId,
  String? clientSecret,
  List<String>? scopes,
  int? port,
  bool? forceNew,
}) async {
  final authCodeGetter = ExternalBrowserAuthCodeFlow(
    cognitoUri: cognitoUri,
    clientId: clientId,
    scopes: scopes,
    port: port ?? 8501,
    forceNew: forceNew,
  );
  final authCode = await authCodeGetter.run();
  return authCode;
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

  final authCodeGetter = ExternalBrowserAuthCodeFlow(
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

Future<void> externalBrowserLogout({
  required Uri cognitoUri,
  required String clientId,
  int? port,
}) async {
  final flow = ExternalBrowserLogoutFlow(
    cognitoUri: cognitoUri,
    clientId: clientId,
    port: port ?? 8501,
  );
  await flow.run();
}
