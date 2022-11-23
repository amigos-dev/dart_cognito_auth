import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
//import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:http/http.dart' as http;
import 'package:args/args.dart';
//import 'package:url_launcher/url_launcher.dart';

const defaultApiUriStr =
    'https://5i7ip3yxdb.execute-api.us-west-2.amazonaws.com/dev/';
const defaultPort = 8501;
// const _useXdg = true;

Uri? optionalParseUri(String? s) => s == null ? null : Uri.parse(s);

String _jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data);

void _logger(String msg, [bool isError = false]) {
  if (isError) {
    stderr.writeln('[ERROR] $msg');
  } else {
    stderr.writeln(msg);
  }
}

Future<void> _launchUri(Uri uri) async {
  String launcher;
  if (Platform.isLinux) {
    launcher = 'xdg-open';
  } else if (Platform.isMacOS) {
    launcher = 'open';
  } else if (Platform.isWindows) {
    launcher = 'start';
  } else {
    throw "Don't know how to launch URL on platform ${Platform.operatingSystem}";
  }

  _logger("launching browser with '$launcher' comand at uri '$uri'");
  // NOTE: This will only work on linux.  Fix for windows/macos.
  final browserLaunch = await Process.run(
    launcher,
    [
      uri.toString(),
    ],
  );
  if (browserLaunch.exitCode != 0) {
    _logger(browserLaunch.stdout);
    _logger(browserLaunch.stderr);
    throw "Could not launch browser with '$launcher' command: exit code ${browserLaunch.exitCode}";
  }
  _logger('Browser launched');
}

class ApiInfo {
  final Uri apiUri;
  final String clientSecret;
  final String clientId;
  final Uri cognitoUri;
  final Uri loginUri;
  final Uri logoutUri;
  final Uri tokenUri;
  final Uri userInfoUri;
  late String tokenAuthHeader;

  ApiInfo._createFinal({
    required this.apiUri,
    required this.clientSecret,
    required this.clientId,
    required this.cognitoUri,
    required this.loginUri,
    required this.logoutUri,
    required this.tokenUri,
    required this.userInfoUri,
  }) {
    final secretValue = "$clientId:$clientSecret";
    final secretBase64 = base64.encode(utf8.encode(secretValue));
    tokenAuthHeader = "Basic $secretBase64";
  }

  ApiInfo._create(
    Uri apiUri,
    String clientSecret,
    String clientId,
    Uri cognitoUri,
    Uri? loginUri,
    Uri? logoutUri,
    Uri? tokenUri,
    Uri? userInfoUri,
  ) : this._createFinal(
          apiUri: apiUri,
          clientSecret: clientSecret,
          clientId: clientId,
          cognitoUri: cognitoUri,
          loginUri: loginUri ?? cognitoUri.resolve('login'),
          logoutUri: logoutUri ?? cognitoUri.resolve('logout'),
          tokenUri: tokenUri ?? cognitoUri.resolve('oauth2/token'),
          userInfoUri: userInfoUri ?? cognitoUri.resolve('oauth2/userInfo'),
        );

  static Future<Map<String, dynamic>> _getApiInfoData(Uri apiUri) async {
    final client = http.Client();
    try {
      final infoUri = apiUri.resolve('info');
      final response = await client.get(infoUri);
      if (response.statusCode != 200) {
        throw HttpException(
          "Bad HTTP status code ${response.statusCode} in API info response",
          uri: infoUri,
        );
      }
      final decodedResponse = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;
      return decodedResponse;
    } finally {
      client.close();
    }
  }

  static Future<ApiInfo> retrieve(Uri apiUri, String clientSecret) async {
    final data = await _getApiInfoData(apiUri);
    // print(_jsonEncode(data));
    final apiInfo = ApiInfo._create(
      apiUri,
      clientSecret,
      data['user_pool_client_id'],
      Uri.parse(data['user_pool_endpoint']),
      optionalParseUri(data['login_uri']),
      optionalParseUri(data['logout_uri']),
      optionalParseUri(data['token_endpoint']),
      optionalParseUri(data['user_info_endpoint']),
    );
    return apiInfo;
  }
}

class AuthorizationException implements Exception {
  final String error;
  final String? description;
  final Uri? uri;

  AuthorizationException(this.error, this.description, this.uri);

  /// Provides a string description of the AuthorizationException.
  @override
  String toString() {
    var header = 'OAuth authorization error ($error)';
    if (description != null) {
      header = '$header: $description';
    } else if (uri != null) {
      header = '$header: $uri';
    }
    return '$header.';
  }
}

class Creds {
  final String accessToken;
  final String idToken;
  final String? refreshToken;
  final int expireSeconds;

  Creds({
    required this.accessToken,
    required this.idToken,
    required this.expireSeconds,
    this.refreshToken,
  });
}

class AsyncAuthCodeGetter {
  final _completer = Completer<String>();
  final ApiInfo apiInfo;
  final int port;
  late Uri loginRedirectUri;

  AsyncAuthCodeGetter({required this.apiInfo, required this.port}) {
    loginRedirectUri = Uri.parse('http://localhost:$port/');
  }

  Uri getLoginUri() {
    final Map<String, String> queryParams = {
      'client_id': apiInfo.clientId,
      'scope': 'email openid',
      'response_type': 'code',
      'redirect_uri': loginRedirectUri.toString()
    };
    final loginUri = apiInfo.cognitoUri
        .resolve('login')
        .replace(queryParameters: queryParams);
    return loginUri;
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
      logRequests(logger: _logger).addHandler(cascade.handler),
      '127.0.0.1', // Do not allow external connections
      port,
    );

    _logger('Serving at http://${server.address.host}:${server.port}/');

    final loginUri = getLoginUri();

    await _launchUri(loginUri);

    final authCode = await _completer.future;

    _logger("auth-getter future completed; shutting down http server");

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
          body: _jsonEncode(
            {
              'code': authCode,
            },
          ),
        );
        _logger("completing auth-getter future");
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
        final Map<String, String> queryParams = {
          'client_id': apiInfo.clientId,
          'scope': 'email openid',
          'response_type': 'code',
          'redirect_uri': loginRedirectUri.toString()
        };
        final redirectUri = apiInfo.cognitoUri
            .resolve('login')
            .replace(queryParameters: queryParams);
        final result = Response(
          200,
          headers: {
            ..._jsonHeaders,
            'Cache-Control': 'no-store',
          },
          body: _jsonEncode(
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

Future<Map<String, dynamic>> getTokensFromAuthCode({
  required ApiInfo apiInfo,
  required String authCode,
  required Uri redirectUri,
}) async {
  final client = http.Client();
  try {
    final Map<String, String> headers = {
      "Authorization": apiInfo.tokenAuthHeader,
    };
    final Map<String, String> queryParameters = {
      "grant_type": "authorization_code",
      "client_id": apiInfo.clientId,
      "code": authCode,
      "redirect_uri": redirectUri.toString(),
    };
    final response = await client.post(
      apiInfo.tokenUri,
      /* Uri.parse('https://ptsv2.com/t/5q3gk-1669016556/post'), */
      headers: headers,
      body: queryParameters,
    );
    if (response.statusCode != 200) {
      throw HttpException(
        "Bad HTTP status code ${response.statusCode} in token endpoint response",
        uri: apiInfo.tokenUri,
      );
    }
    // print(response.toString());
    final decodedResponse = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;
    // print(decodedResponse.toString());
    return decodedResponse;
  } finally {
    client.close();
  }
}

Future<Creds> getCredsFromAuthCode({
  required ApiInfo apiInfo,
  required String authCode,
  required Uri redirectUri,
}) async {
  final tokens = await getTokensFromAuthCode(
    apiInfo: apiInfo,
    authCode: authCode,
    redirectUri: redirectUri,
  );
  final creds = Creds(
    accessToken: tokens['access_token'],
    idToken: tokens['id_token'],
    refreshToken: tokens['refresh_token'],
    expireSeconds: tokens['expires_in'],
  );
  return creds;
}

Future<Creds> authenticate(
  ApiInfo apiInfo,
  int? port,
) async {
  final authCodeGetter =
      AsyncAuthCodeGetter(apiInfo: apiInfo, port: port ?? 8501);
  final authCode = await authCodeGetter.run();
  final creds = await getCredsFromAuthCode(
    apiInfo: apiInfo,
    authCode: authCode,
    redirectUri: authCodeGetter.loginRedirectUri,
  );
  return creds;
}

Uri ensureUriEndsWithSlash(Uri uri) {
  String uriStr = uri.toString();
  if (!uriStr.endsWith('/')) {
    uri = Uri.parse('$uriStr/');
  }
  return uri;
}

Future<void> main(List<String> arguments) async {
  exitCode = 0; // presume success
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Display usage info.',
    )
    ..addOption(
      'client-secret',
      abbr: 's',
      defaultsTo: null,
      help: 'Set the OAUTH2 client secret. '
          'By default, environment variable CLIENT_SECRET is used.',
    )
    ..addOption(
      'api-uri',
      abbr: 'u',
      defaultsTo: null,
      help: 'Set the base API URI. By default, environment variable '
          'API_URI is used; if that is not set, "$defaultApiUriStr" is used.',
    )
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: "$defaultPort",
      help:
          ' Set the localhost port use for intercepting login redirect HTTP request. '
          'http://localhost:<port>/ must be be an approved redirect URI in Cognito. '
          'By default, $defaultPort is used.',
    );

  ArgResults argResults;
  String clientSecret;
  try {
    argResults = parser.parse(arguments);
    if (argResults['help']) {
      stdout.writeln(parser.usage);
      return;
    }
    clientSecret = argResults['client-secret'] ??
        Platform.environment['CLIENT_SECRET'] ??
        '';
    if (clientSecret == '') {
      throw const FormatException(
        'OAUTH2 client secret must be provided with --client-secret or in environment variable CLIENT_SECRET',
      );
    }
  } on FormatException catch (e) {
    stderr.writeln(parser.usage);
    stderr.writeln("$e");
    exitCode = 1;
    return;
  }

  final String apiUriStr = argResults['api-uri'] ??
      Platform.environment['API_URI'] ??
      defaultApiUriStr;
  var apiUri = ensureUriEndsWithSlash(Uri.parse(apiUriStr));

  final port = int.parse(argResults['port']);

  final apiInfo = await ApiInfo.retrieve(apiUri, clientSecret);

  final creds = await authenticate(apiInfo, port);
  final summary = {
    'accessToken': creds.accessToken,
    'idToken': creds.idToken,
    'refreshToken': creds.refreshToken,
    'expireSeconds': creds.expireSeconds,
  };

  const encoder = JsonEncoder.withIndent('  ');
  final prettyprint = encoder.convert(summary);
  stdout.writeln(prettyprint);
}
