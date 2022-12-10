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
import 'async_key_value_store.dart';

typedef CredsListener = void Function(Creds? creds);

class CognitoAuthorizer {
  final AuthConfig authConfig;
  Creds? _creds;
  List<Completer<Creds>> refreshWaiters = [];
  bool refreshing = false;
  late Uri _tokenUri;
  final _httpClient = http.Client();
  String? initialRefreshToken;
  String? _persistedRefreshToken;
  bool _havePersistedRefreshToken = false;
  final _listeners = <CredsListener>{};
  final Uri loginCallbackUri;
  late Uri logoutCallbackUri;
  late AsyncKeyValueStore? refreshTokenStore;

  CognitoAuthorizer({
    required this.authConfig,
    this.initialRefreshToken,
    required this.loginCallbackUri,
    this.refreshTokenStore,
    Uri? logoutCallbackUri,
  }) {
    _tokenUri = authConfig.getTokenUri();
    if (logoutCallbackUri == null) {
      final qp = Map<String, String>.from(loginCallbackUri.queryParameters);
      qp['action'] = 'logout';
      this.logoutCallbackUri = loginCallbackUri.replace(queryParameters: qp);
    } else {
      this.logoutCallbackUri = logoutCallbackUri;
    }
  }

  String get clientId => authConfig.clientId;
  String? get clientSecret => authConfig.clientSecret;
  Uri get cognitoUri => authConfig.cognitoUri;
  int get refreshGraceSeconds => authConfig.refreshGraceSeconds;
  List<String>? get scopes => authConfig.scopes;

  Creds? get creds => _creds;
  set creds(Creds? creds) {
    if (creds != null) {
      _bgSetPersistedRefreshToken(creds.refreshToken);
    }
    _creds = creds;
    _notifyListeners(creds);
  }

  Future<void> asyncSetCreds(Creds? creds) async {
    if (creds != null) {
      await setPersistedRefreshToken(creds.refreshToken);
    }
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

  String get secureStorageRefreshTokenKey {
    return "${authConfig.secureStorageRefreshTokenKeyPrefix}-$clientId";
  }

  Future<String?> getPersistedRefreshToken() async {
    if (!_havePersistedRefreshToken) {
      _persistedRefreshToken = await refreshTokenStore?.read(key: secureStorageRefreshTokenKey);
      _havePersistedRefreshToken = true;
    }
    return _persistedRefreshToken;
  }

  Future<void> setPersistedRefreshToken(String? value) async {
    if (!_havePersistedRefreshToken || value != _persistedRefreshToken) {
      // We assume its going to work, since there's no effective mitigation if it fails
      // and we don't want to reperatedly try to write.
      _persistedRefreshToken = value;
      _havePersistedRefreshToken = true;
      if (refreshTokenStore != null) {
        if (value == null) {
          await refreshTokenStore!.delete(key: secureStorageRefreshTokenKey);
        } else {
          await refreshTokenStore!.write(key: secureStorageRefreshTokenKey, value: value);
        }
      }
    }
  }

  void _bgSetPersistedRefreshToken(String? value) {
    setPersistedRefreshToken(value).onError((e, stackTrace) {
      developer.log("setPersistedRefreshToken failed, e: '$e', stackTrace: '$stackTrace'");
    });
  }

  Future<void> deletePersistedRefreshToken() async {
    if (!_havePersistedRefreshToken || _persistedRefreshToken != null) {
      refreshTokenStore?.delete(key: secureStorageRefreshTokenKey);
      _persistedRefreshToken = null;
      _havePersistedRefreshToken = true;
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

  /// Refreshes the credentials and returns the new credentials. Aggregates
  /// multiple overlapping refresh requests into a single request.
  /// Uses current creds refresh token, persisted refresh token,
  /// or refresh token provided at construction, as appropriate.
  Future<Creds> refresh() async {
    final completer = Completer<Creds>();
    refreshWaiters.add(completer);
    if (!refreshing) {
      try {
        refreshing = true;
        var refreshToken = creds?.refreshToken ?? initialRefreshToken ?? await getPersistedRefreshToken();
        initialRefreshToken = null;
        if (refreshToken == null) {
          throw AuthorizationException("Cannot refresh Creds--No refresh token available");
        }
        final newCreds = await refreshCreds(
          tokenUri: _tokenUri,
          clientId: clientId,
          clientSecret: clientSecret,
          refreshToken: refreshToken,
          httpClient: _httpClient,
        );
        await setPersistedRefreshToken(newCreds.refreshToken);
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

  /// If there are no creds or the access token is stale, refreshes
  /// the creds. Returns existing or new credentials. Aggregates
  /// multiple overlapping refresh requests into a single request.
  /// Uses current creds' refresh token, persisted refresh token,
  /// or refresh token provided at construction, as appropriate.
  Future<Creds> refreshIfStale({int? minRemainingSeconds}) async {
    minRemainingSeconds = minRemainingSeconds ?? authConfig.refreshGraceSeconds;
    var freshCreds = creds;
    while (freshCreds == null || freshCreds.getRemainingSeconds() <= minRemainingSeconds) {
      freshCreds = await refresh();
    }
    return freshCreds;
  }

  /// Returns new creds, including a new refresh token, generated from an authorization
  /// code provided on redirect back from IDP's hosted login UI.
  /// The new refresh token is persisted in secure storage if enabled.
  Future<Creds> fromAuthCode(String authCode) async {
    final newCreds = await getCredsFromAuthCode(
      tokenUri: _tokenUri,
      clientId: clientId,
      clientSecret: clientSecret,
      authCode: authCode,
      redirectUri: loginCallbackUri,
      httpClient: _httpClient,
    );
    await setPersistedRefreshToken(newCreds.refreshToken);
    creds = newCreds;
    // Anyone waiting on refresh can also be completed
    _completeRefresh(newCreds);
    return newCreds;
  }

  /// Clear all user credentials in response to a logout request, including
  /// any persisted refresh token. This does not clear cached login state in
  /// Cognito's hosted UI--for that you must navigate to the logout URI.
  void clear() {
    // Cancel any pending refresh requests
    try {
      throw AuthorizationException("Cannot refresh Creds--Logout while refreshing");
    } catch (e, stackTrace) {
      _completeRefreshError(e, stackTrace);
    }
    creds = null;
    _bgSetPersistedRefreshToken(null);
  }

  Future<void> asyncClear() async {
    // Cancel any pending refresh requests
    try {
      throw AuthorizationException("Cannot refresh Creds--Logout while refreshing");
    } catch (e, stackTrace) {
      _completeRefreshError(e, stackTrace);
    }
    creds = null;
    await setPersistedRefreshToken(null);
  }

  Future<UserInfo> getUserInfo() async {
    final freshCreds = await refreshIfStale();
    final result = await UserInfo.retrieve(cognitoUri: cognitoUri, accessToken: freshCreds.accessToken);
    return result;
  }

  Uri getLoginUri({bool? forceNew}) =>
      util.getLoginUri(cognitoUri: cognitoUri, clientId: clientId, redirectUri: loginCallbackUri, forceNew: forceNew);

  Uri getLogoutUri() => util.getLogoutUri(cognitoUri: cognitoUri, clientId: clientId, redirectUri: logoutCallbackUri);
}
