import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'util.dart';
import 'util.dart' as util;
import 'creds.dart';

class ApiInfo {
  final Uri apiUri;
  final String? clientSecret;
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
    String? clientSecret,
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

  static Future<ApiInfo> retrieve(Uri apiUri, String? clientSecret) async {
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

  Future<Map<String, dynamic>> getTokensFromAuthCode({
    required String authCode,
    required Uri redirectUri,
  }) async {
    return await util.getTokensFromAuthCode(
        tokenUri: tokenUri,
        clientId: clientId,
        clientSecret: clientSecret,
        authCode: authCode,
        redirectUri: redirectUri);
  }

  Future<Creds> getCredsFromAuthCode({
    required String authCode,
    required Uri redirectUri,
  }) async {
    return await util.getCredsFromAuthCode(
        tokenUri: tokenUri,
        clientId: clientId,
        clientSecret: clientSecret,
        authCode: authCode,
        redirectUri: redirectUri);
  }
}
