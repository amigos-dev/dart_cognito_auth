import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:cognito_auth/cognito_auth/cognito_auth_desktop_cli/cognito_auth_desktop_cli.dart';

const defaultApiUriStr = 'https://5i7ip3yxdb.execute-api.us-west-2.amazonaws.com/dev/';
const defaultPort = 8501;

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
    ..addFlag(
      'force-new',
      abbr: 'f',
      negatable: false,
      help: 'Do not use refresh token or cached Cognito login; force a new login.',
    )
    ..addFlag(
      'logout',
      abbr: 'z',
      negatable: false,
      help: 'Do not use login; instead, logout. Removes cached refresh token and cached browser auth state.',
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
      help: 'Set the localhost port use for intercepting login redirect HTTP request. '
          'http://localhost:<port>/ must be be an approved redirect URI in Cognito.',
    );

  ArgResults argResults;
  String clientSecret;
  try {
    argResults = parser.parse(arguments);
    if (argResults['help']) {
      stdout.writeln(parser.usage);
      return;
    }
    clientSecret = argResults['client-secret'] ?? Platform.environment['CLIENT_SECRET'] ?? '';
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

  final String apiUriStr = argResults['api-uri'] ?? Platform.environment['API_URI'] ?? defaultApiUriStr;
  var apiUri = ensureUriEndsWithSlash(Uri.parse(apiUriStr));
  final bool shouldLogout = argResults['logout'] as bool;
  final bool forceNew = argResults['force-new'] as bool;

  final port = int.parse(argResults['port']);

  final authConfig = await AuthConfig.fromApiInfo(apiUri: apiUri, clientSecret: clientSecret);

  final authorizer = DesktopCliCognitoAuthorizer(authConfig: authConfig, port: port);

  if (shouldLogout) {
    await authorizer.logout();
    stderr.writeln("Successfully logged out...");
  } else {
    final creds = await authorizer.login(forceNew: forceNew);

    final summary = {
      'accessToken': creds.accessToken.rawToken,
      'idToken': creds.idToken.rawToken,
      'refreshToken': creds.refreshToken,
      'expireSeconds': creds.expireSeconds,
    };

    const encoder = JsonEncoder.withIndent('  ');
    final prettyprint = encoder.convert(summary);
    stdout.writeln(prettyprint);
  }
  exit(0);
}
