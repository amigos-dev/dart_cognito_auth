import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'util.dart';
import 'external_browser.dart';
import 'api_info.dart';

const defaultApiUriStr =
    'https://5i7ip3yxdb.execute-api.us-west-2.amazonaws.com/dev/';
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

  final creds = await externalBrowserAuthenticate(
    cognitoUri: apiInfo.cognitoUri,
    clientId: apiInfo.clientId,
    clientSecret: clientSecret,
    port: port,
  );

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
