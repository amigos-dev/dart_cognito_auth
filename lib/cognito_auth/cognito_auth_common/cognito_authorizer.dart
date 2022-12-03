import 'dart:async';
//import 'dart:convert';
import 'dart:developer' as developer;
import 'authorization_exception.dart';
import 'util.dart';
import 'util.dart' as util;
import 'package:http/http.dart' as http;
import 'creds.dart';
import "auth_config.dart";
import "user_info.dart";
import "access_token.dart";
import "id_token.dart";

typedef CredsListener = void Function(Creds? creds);

class CognitoAuthorizer {
  final AuthConfig authConfig;
  Creds? _creds;
  List<Completer<Creds>> refreshWaiters = [];
  bool refreshing = false;
  late Uri _tokenUri;
  final _httpClient = http.Client();
  String? initialRefreshToken;
  final _listeners = <CredsListener>{};
  final Uri loginCallbackUri;

  CognitoAuthorizer({required this.authConfig, this.initialRefreshToken, required this.loginCallbackUri}) {
    _tokenUri = authConfig.getTokenUri();
  }

  String get clientId => authConfig.clientId;
  String? get clientSecret => authConfig.clientSecret;
  Uri get cognitoUri => authConfig.cognitoUri;
  int get refreshGraceSeconds => authConfig.refreshGraceSeconds;
  List<String>? get scopes => authConfig.scopes;

  Creds? get creds => _creds;
  set creds(Creds? creds) {
    _creds = creds;
    _notifyListeners(creds);
  }

  AccessToken? get accessToken => creds?.accessToken;
  IdToken? get idToken => creds?.idToken;
  String? get rawAccessToken => accessToken?.rawToken;
  String? get rawIdToken => idToken?.rawToken;
  String? get refreshToken => creds?.refreshToken ?? initialRefreshToken;

  void addListener(CredsListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CredsListener listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners(Creds? creds) {
    final listeners = _listeners;
    for (var listener in listeners) {
      try {
        listener(creds);
      } catch (e, stackTrace) {
        developer.log("Exception in CredsNotifyListener (discarded): $e, stackTrace=$stackTrace");
      }
    }
  }

  void _completeRefreshError(Object error, [StackTrace? stackTrace]) {
    final waiters = refreshWaiters;
    refreshWaiters = [];
    refreshing = false;
    for (var waiter in waiters) {
      waiter.completeError(error, stackTrace);
    }
  }

  void _completeRefresh(Creds creds) {
    final waiters = refreshWaiters;
    refreshWaiters = [];
    refreshing = false;
    for (var waiter in waiters) {
      waiter.complete(creds);
    }
  }

  // Refreshes the credentials and returns the new credentials. Aggregates
  // multiple overlapping refresh requests into a single request.
  Future<Creds> refresh() async {
    final completer = Completer<Creds>();
    refreshWaiters.add(completer);
    if (!refreshing) {
      try {
        refreshing = true;
        final refreshToken = creds?.refreshToken ?? initialRefreshToken;
        if (refreshToken == null) {
          throw AuthorizationException("Cannot refresh Creds--No refresh token available");
        }
        initialRefreshToken = null;
        final newCreds = await refreshCreds(
          tokenUri: _tokenUri,
          clientId: clientId,
          clientSecret: clientSecret,
          refreshToken: refreshToken,
          httpClient: _httpClient,
        );
        creds = newCreds;
        _completeRefresh(newCreds);
      } catch (e, stackTrace) {
        _completeRefreshError(e, stackTrace);
      }
    }
    final result = await completer.future;
    return result;
  }

  double getRemainingSeconds() {
    return (creds == null) ? 0.0 : creds!.getRemainingSeconds();
  }

  /// Returns true if the number of remaining seconds on the access token is
  /// less than an acceptable grace period. If minRemainingSeconds is
  /// not provided, then authConfig.refreshGraceSeconds is used.
  bool isStale(int? minRemainingSeconds) {
    minRemainingSeconds = minRemainingSeconds ?? authConfig.refreshGraceSeconds;
    return (creds == null) || creds!.getRemainingSeconds() <= minRemainingSeconds;
  }

  Future<Creds> refreshIfStale({int? minRemainingSeconds}) async {
    minRemainingSeconds = minRemainingSeconds ?? authConfig.refreshGraceSeconds;
    var freshCreds = creds;
    while (freshCreds == null || freshCreds.getRemainingSeconds() <= minRemainingSeconds) {
      freshCreds = await refresh();
    }
    return freshCreds;
  }

  Future<Creds> fromAuthCode(String authCode) async {
    final newCreds = await getCredsFromAuthCode(
      tokenUri: _tokenUri,
      clientId: clientId,
      clientSecret: clientSecret,
      authCode: authCode,
      redirectUri: loginCallbackUri,
      httpClient: _httpClient,
    );
    creds = newCreds;
    // Anyone waiting on refresh can also be completed
    _completeRefresh(newCreds);
    return newCreds;
  }

  void clear() {
    creds = null;
    try {
      throw AuthorizationException("Cannot refresh Creds--Logout while refreshing");
    } catch (e, stackTrace) {
      _completeRefreshError(e, stackTrace);
    }
  }

  Future<UserInfo> getUserInfo() async {
    final freshCreds = await refreshIfStale();
    final result = await UserInfo.retrieve(cognitoUri: cognitoUri, accessToken: freshCreds.accessToken);
    return result;
  }

  Uri getLoginUri({bool? forceNew}) =>
      util.getLoginUri(cognitoUri: cognitoUri, clientId: clientId, redirectUri: loginCallbackUri, forceNew: forceNew);
}
