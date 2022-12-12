import 'dart:io';
import 'dart:convert';
import 'access_token.dart';
import 'id_token.dart';
import 'refresh_token.dart';
import 'package:http/http.dart' as http;
import 'creds.dart';
import 'dart:developer' as developer;

Uri? optionalParseUri(String? s) => s == null ? null : Uri.parse(s);

String jsonEncode(Object? data) => const JsonEncoder.withIndent(' ').convert(data);

Uri ensureUriEndsWithSlash(Uri uri) {
  String uriStr = uri.toString();
  if (!uriStr.endsWith('/')) {
    uri = Uri.parse('$uriStr/');
  }
  return uri;
}

Uri getLoginUri({
  required Uri cognitoUri,
  required String clientId,
  required Uri redirectUri,
  List<String>? scopes,
  bool? forceNew,
}) {
  forceNew = forceNew ?? false;
  Map<String, String> queryParams = {'client_id': clientId, 'response_type': 'code', 'redirect_uri': redirectUri.toString()};
  if (scopes != null && scopes.isNotEmpty) {
    queryParams['scope'] = scopes.join(' ');
  }
  // In cognito, the logout endpoint can also act as a login endpoint--it works the same except that
  // any cached login state is purged before initiating a clean login...
  final loginUri = cognitoUri.resolve(forceNew ? 'logout' : 'login').replace(queryParameters: queryParams);
  return loginUri;
}

Uri getLogoutUri({
  required Uri cognitoUri,
  required String clientId,
  required Uri redirectUri,
}) {
  Map<String, String> queryParams = {'client_id': clientId, 'logout_uri': redirectUri.toString()};
  final logoutUri = cognitoUri.resolve('logout').replace(queryParameters: queryParams);
  return logoutUri;
}

String getTokenAuthorizationHeader({
  required String clientId,
  required String clientSecret,
}) {
  final secretValue = "$clientId:$clientSecret";
  final secretBase64 = base64.encode(utf8.encode(secretValue));
  final tokenAuthHeader = "Basic $secretBase64";
  return tokenAuthHeader;
}

Future<Map<String, dynamic>> getTokensFromAuthCode({
  required Uri tokenUri,
  required String clientId,
  String? clientSecret,
  required String authCode,
  required Uri redirectUri,
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  try {
    final Map<String, String> headers = {};
    if (clientSecret != null) {
      headers["Authorization"] = getTokenAuthorizationHeader(clientId: clientId, clientSecret: clientSecret);
    }
    final Map<String, String> queryParameters = {
      "grant_type": "authorization_code",
      "client_id": clientId,
      "code": authCode,
      "redirect_uri": redirectUri.toString(),
    };
    developer.log('Getting tokens from "$tokenUri", headers=$headers, params=$queryParameters');
    final response = await client.post(
      tokenUri,
      headers: headers,
      body: queryParameters,
    );
    if (response.statusCode != 200) {
      throw HttpException(
        "Bad HTTP status code ${response.statusCode} in token endpoint response",
        uri: tokenUri,
      );
    }
    // print(response.toString());
    final decodedResponse = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;
    // print(decodedResponse.toString());
    return decodedResponse;
  } finally {
    if (httpClient == null) {
      client.close();
    }
  }
}

Future<Creds> getCredsFromAuthCode({
  required Uri tokenUri,
  required String clientId,
  String? clientSecret,
  required String authCode,
  required Uri redirectUri,
  http.Client? httpClient,
}) async {
  final localAuthTime = DateTime.now().toUtc();
  final tokens = await getTokensFromAuthCode(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    authCode: authCode,
    redirectUri: redirectUri,
    httpClient: httpClient,
  );
  final rawRefreshToken = tokens['refresh_token'] as String?;
  final refreshToken = (rawRefreshToken == null) ? null : RefreshToken(rawToken: rawRefreshToken, createTime: localAuthTime);
  final rawAccessToken = tokens['access_token'] as String;
  final rawIdToken = tokens['id_token'] as String;
  final expireDuration = Duration(seconds: tokens['expires_in'] as int);

  final accessToken = AccessToken(rawToken: rawAccessToken, localAuthTime: localAuthTime);
  final idToken = IdToken(rawToken: rawIdToken, localAuthTime: localAuthTime);

  final creds = Creds(
    accessToken: accessToken,
    idToken: idToken,
    refreshToken: refreshToken,
    expireDuration: expireDuration,
  );
  return creds;
}

Future<Map<String, dynamic>> refreshTokens({
  required Uri tokenUri,
  required String clientId,
  String? clientSecret,
  required String rawRefreshToken,
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  try {
    final Map<String, String> headers = {};
    if (clientSecret != null) {
      headers["Authorization"] = getTokenAuthorizationHeader(clientId: clientId, clientSecret: clientSecret);
    }
    final Map<String, String> queryParameters = {
      "grant_type": "refresh_token",
      "client_id": clientId,
      "refresh_token": rawRefreshToken,
    };
    developer.log('Getting tokens from "$tokenUri", headers=$headers, params=$queryParameters');
    final response = await client.post(
      tokenUri,
      headers: headers,
      body: queryParameters,
    );
    if (response.statusCode != 200) {
      throw HttpException(
        "Bad HTTP status code ${response.statusCode} in token endpoint response",
        uri: tokenUri,
      );
    }
    // print(response.toString());
    final decodedResponse = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;
    // print(decodedResponse.toString());
    return decodedResponse;
  } finally {
    if (httpClient == null) {
      client.close();
    }
  }
}

Future<Creds> refreshCreds({
  required Uri tokenUri,
  required String clientId,
  String? clientSecret,
  required RefreshToken refreshToken,
  http.Client? httpClient,
}) async {
  final localAuthTime = DateTime.now().toUtc();
  final tokens = await refreshTokens(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    rawRefreshToken: refreshToken.rawToken,
    httpClient: httpClient,
  );
  final rawAccessToken = tokens['access_token'] as String;
  final rawIdToken = tokens['id_token'] as String;
  final expireDuration = Duration(seconds: tokens['expires_in'] as int);
  final accessToken = AccessToken(rawToken: rawAccessToken, localAuthTime: localAuthTime);
  final idToken = IdToken(rawToken: rawIdToken, localAuthTime: localAuthTime);

  final creds = Creds(
    accessToken: accessToken,
    idToken: idToken,
    refreshToken: refreshToken,
    expireDuration: expireDuration,
  );
  return creds;
}

Future<Map<String, dynamic>> getUserOauthMetadata({
  required Uri userInfoUri,
  required String accessToken,
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  try {
    final Map<String, String> headers = {'Authorization': 'Bearer $accessToken'};
    final response = await client.get(
      userInfoUri,
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw HttpException(
        "Bad HTTP status code ${response.statusCode} in userInfo endpoint response",
        uri: userInfoUri,
      );
    }
    final decodedResponse = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;
    return decodedResponse;
  } finally {
    if (httpClient == null) {
      client.close();
    }
  }
}
