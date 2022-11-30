import 'dart:async';
import 'util.dart';
import 'access_token.dart';

class UserInfo {
  final Map<String, dynamic> data;
  late String? email;
  late String? sub;
  late bool emailVerified;
  late String? username;

  UserInfo({
    required this.data,
  }) {
    email = data['email'] as String?;
    sub = data['sub'] as String?;
    username = data['username'] as String?;
    final emailVerifiedStr = (data['email_verified'] ?? "false") as String;
    emailVerified = emailVerifiedStr == 'true';
  }

  @override
  String toString() {
    return "UserInfo($data)";
  }

  static Future<UserInfo> retrieve(
      {required Uri cognitoUri, required AccessToken accessToken}) async {
    final userInfoUri = cognitoUri.resolve("oauth2/userInfo");
    final data = await getUserOauthMetadata(
      userInfoUri: userInfoUri,
      accessToken: accessToken.rawToken,
    );
    final userInfo = UserInfo(data: data);
    return userInfo;
  }
}
