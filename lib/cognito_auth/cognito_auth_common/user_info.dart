import 'dart:async';
import 'util.dart';
import 'access_token.dart';
import 'package:meta/meta.dart';

@immutable
class UserInfo {
  final Map<String, dynamic> data;

  const UserInfo({
    required this.data,
  });

  String? get email {
    return data['email'] as String?;
  }

  String? get sub {
    return data['sub'] as String?;
  }

  String? get userId {
    return data['username'] as String?;
  }

  bool get emailVerified {
    final emailVerifiedStr = (data['email_verified'] ?? "false") as String;
    return emailVerifiedStr == 'true';
  }

  @override
  String toString() {
    return "UserInfo($data)";
  }

  static Future<UserInfo> retrieve({required Uri cognitoUri, required AccessToken accessToken}) async {
    final userInfoUri = cognitoUri.resolve("oauth2/userInfo");
    final data = await getUserOauthMetadata(
      userInfoUri: userInfoUri,
      accessToken: accessToken.rawToken,
    );
    final userInfo = UserInfo(data: data);
    return userInfo;
  }
}
