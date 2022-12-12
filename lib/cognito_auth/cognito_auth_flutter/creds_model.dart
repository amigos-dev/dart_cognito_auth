import 'dart:async';
import 'dart:io';
import '../cognito_auth_common/cognito_auth_common.dart';
import '../browser_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import "package:universal_html/html.dart" as html;
import "flutter_cognito_authorizer.dart";

const defaultPortStr = '8501';
const portStr = String.fromEnvironment('PORT', defaultValue: defaultPortStr);
final port = int.parse(portStr);

const defaultUrlScheme = 'dev.amigos.cognito-auth';
const urlScheme = String.fromEnvironment('COGNITO_AUTH_URL_SCHEME', defaultValue: defaultUrlScheme);

Uri? _defaultLoginCallbackUri;
Uri get defaultLoginCallbackUri {
  var defaultLoginCallbackUri = _defaultLoginCallbackUri;
  if (defaultLoginCallbackUri == null) {
    if (kIsWeb) {
      // On the web, logins will redirect to on-login.html, which is in the ./web
      // subdirectory of the package, and is served statically.
      defaultLoginCallbackUri = Uri.base.removeFragment().replace(queryParameters: {}).resolve('on-login.html');
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // NOTE: macOS should be using integrated browser strategy, but
      //       flutter_web_auth throws an exception in swift, so for now
      //       we will launch an external browser.
      defaultLoginCallbackUri = Uri.parse('http://localhost:$port/');
    } else {
      // On platforms that support an integrated browser login with a custom url scheme
      // for callbacks, we will use the custom url scheme
      defaultLoginCallbackUri = Uri.parse('$urlScheme://');
    }
    _defaultLoginCallbackUri = defaultLoginCallbackUri;
  }
  return defaultLoginCallbackUri;
}

set defaultLoginCallbackUri(Uri uri) {
  _defaultLoginCallbackUri = uri;
}

class CredsModel with ChangeNotifier {
  late CognitoAuthorizer _authorizer;
  List<Completer<Creds>> _loginWaiters = [];
  List<Completer<void>> _logoutWaiters = [];

  CredsModel({
    required AuthConfig authConfig,
    String? initialRefreshToken,
    Uri? loginCallbackUri,
    bool initialLoginOrRefresh = true,
  }) {
    loginCallbackUri = loginCallbackUri ?? defaultLoginCallbackUri;
    _authorizer = FlutterCognitoAuthorizer(authConfig: authConfig, loginCallbackUri: loginCallbackUri);
    _authorizer.addListener(_onAuthorizerCredsChanged);
    if (kIsWeb) {
      developer.log("CredsModel: Adding window message listener");
      html.window.addEventListener("message", _onWindowMessageEvent);
    }
    if (initialLoginOrRefresh) {
      loginOrRefresh().then((value) => null).onError((error, stackTrace) {
        developer.log("Initial loginOrRefresh failed, error: '$error', stackTrace: $stackTrace");
      });
    }
  }

  AuthConfig get authConfig => _authorizer.authConfig;
  String get clientId => _authorizer.clientId;
  String? get clientSecret => _authorizer.clientSecret;
  Uri get cognitoUri => _authorizer.cognitoUri;
  AccessToken? get accessToken => creds?.accessToken;
  String? get rawAccessToken => accessToken?.rawToken;
  IdToken? get idToken => creds?.idToken;
  RefreshToken? get refreshToken => _authorizer.refreshToken;
  String? get rawRefreshToken => refreshToken?.rawToken;
  List<String>? get scopes => _authorizer.scopes;
  Uri get loginCallbackUri => _authorizer.loginCallbackUri;
  Uri get logoutCallbackUri => _authorizer.logoutCallbackUri;

  Creds? get creds {
    return _authorizer.creds;
  }

  set creds(Creds? creds) {
    _authorizer.creds = creds;
  }

  Future<void> asyncSetCreds(Creds? creds) async {
    await _authorizer.asyncSetCreds(creds);
  }

  bool get isLoggedIn => _authorizer.isLoggedIn;

  Future<Creds> refresh() async => _authorizer.refresh();

  Duration getAccessTokenRemainingDuration({Duration graceDuration = Duration.zero}) =>
      _authorizer.getAccessTokenRemainingDuration(graceDuration: graceDuration);

  Duration getIdTokenRemainingDuration({Duration graceDuration = Duration.zero}) =>
      _authorizer.getIdTokenRemainingDuration(graceDuration: graceDuration);

  Future<Duration> getPersistedRefreshTokenRemainingDuration({Duration graceDuration = Duration.zero}) async =>
      await _authorizer.getPersistedRefreshTokenRemainingDuration(graceDuration: graceDuration);

  bool accessTokenIsStale({Duration? graceDuration}) => _authorizer.accessTokenIsStale(graceDuration: graceDuration);
  bool idTokenIsStale({Duration? graceDuration}) => _authorizer.idTokenIsStale(graceDuration: graceDuration);
  Future<bool> persistedRefreshTokenIsStale({Duration? graceDuration}) async =>
      await _authorizer.persistedRefreshTokenIsStale(graceDuration: graceDuration);

  Future<Creds> refreshIfAccessTokenIsStale({Duration? graceDuration}) async => _authorizer.refreshIfAccessTokenIsStale(graceDuration: graceDuration);

  Future<Creds> fromAuthCode(String authCode) async => _authorizer.fromAuthCode(authCode);

  void clear() => _authorizer.clear();

  Future<UserInfo> getUserInfo() async => _authorizer.getUserInfo();

  Uri getLoginUri({bool? forceNew}) => _authorizer.getLoginUri(forceNew: forceNew);
  Uri getLogoutUri() => _authorizer.getLogoutUri();

  Future<Creds> login({bool? forceNew}) async {
    forceNew = forceNew ?? false;
    final loginUri = getLoginUri(forceNew: forceNew);
    if (forceNew) {
      await asyncSetCreds(null);
    }

    Creds result;
    if (kIsWeb) {
      final completer = Completer<Creds>();
      _loginWaiters.add(completer);
      try {
        html.window.open(loginUri.toString(), "_blank", 'location=yes');
      } catch (e, stackTrace) {
        _onAuthError(e, stackTrace);
      }
      result = await completer.future;
    } else {
      result = await browserAuthenticate(
        cognitoUri: cognitoUri,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes,
        callbackUri: loginCallbackUri,
        forceNew: forceNew,
      );
    }
    await asyncSetCreds(result);
    return result;
  }

  Future<void> logout() async {
    final logoutUri = getLogoutUri();
    await asyncSetCreds(null);

    if (kIsWeb) {
      final completer = Completer<void>();
      _logoutWaiters.add(completer);
      try {
        html.window.open(logoutUri.toString(), "_blank", 'location=yes');
      } catch (e, stackTrace) {
        _onLogoutError(e, stackTrace);
      }
      await completer.future;
    } else {
      await browserLogout(
        cognitoUri: cognitoUri,
        clientId: clientId,
        callbackUri: logoutCallbackUri,
      );
    }
  }

  Future<Creds> loginOrRefresh() async {
    final loginUri = getLoginUri(forceNew: false);
    Creds? result;

    if (!await persistedRefreshTokenIsStale()) {
      try {
        result = await _authorizer.refresh();
      } on AuthorizationException catch (e) {
        developer.log("loginOrRefresh: Refresh credentials failed, falling back to browser login: $e");
        // fall through to regular authorization code flow
      }
    }

    if (result == null) {
      if (kIsWeb) {
        final completer = Completer<Creds>();
        _loginWaiters.add(completer);
        try {
          html.window.open(loginUri.toString(), "_blank", 'location=yes');
        } catch (e, stackTrace) {
          _onAuthError(e, stackTrace);
        }
        result = await completer.future;
      } else {
        result = await browserAuthenticate(
          cognitoUri: cognitoUri,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes,
          callbackUri: loginCallbackUri,
        );
      }
      await asyncSetCreds(result);
    }
    return result;
  }

  void _onAuthorizerCredsChanged(Creds? creds) {
    notifyListeners();
    if (creds != null) {
      final waiters = _loginWaiters;
      _loginWaiters = [];
      for (var waiter in waiters) {
        waiter.complete(creds);
      }
    }
  }

  Future<void> _asyncHandleAuthCode(String authCode) async {
    await fromAuthCode(authCode);
  }

  void _onLogoutComplete() async {
    final waiters = _logoutWaiters;
    _logoutWaiters = [];
    for (var waiter in waiters) {
      waiter.complete();
    }
  }

  void _onLogoutError(Object? e, dynamic stackTrace) async {
    developer.log("CredsModel._onLogoutError: error='$e', stackTrace='$stackTrace'");
    final waiters = _logoutWaiters;
    _logoutWaiters = [];
    for (var waiter in waiters) {
      waiter.completeError(e ?? "Logout Error", stackTrace);
    }
  }

  _onAuthError(Object? e, dynamic stackTrace) {
    developer.log("CredsModel._onAuthError: error='$e', stackTrace='$stackTrace'");
    final waiters = _loginWaiters;
    _loginWaiters = [];
    for (var waiter in waiters) {
      waiter.completeError(e ?? "Auth Error", stackTrace);
    }
  }

  void _onAuthCodeReceived(String authCode) {
    _asyncHandleAuthCode(authCode).onError((e, stackTrace) {
      _onAuthError(e, stackTrace);
    });
  }

  void _onWindowMessageEvent(html.Event event) {
    if (event is html.MessageEvent) {
      //final messageEvent = event as html.MessageEvent;
      final data = Map<String, dynamic>.from(event.data);
      developer.log("Got message-event, event data=$data");
      if (data['name'] == 'on-login') {
        String queryString = data['query-string'] ?? '';
        if (queryString.startsWith('?')) {
          queryString = queryString.substring(1);
        }

        developer.log("Got on-login message event, query-string=$queryString");
        final queryParameters = Uri.base.replace(query: queryString).queryParameters;
        developer.log("Got on-login message event, query-parameters=$queryParameters");
        final String? action = queryParameters['action'];
        if (action == 'logout') {
          developer.log("Got successful logout callback");
          _onLogoutComplete();
          final sourceWindow = event.source as html.WindowBase?;
          if (sourceWindow != null) {
            sourceWindow.close();
          }
        } else {
          final String? code = queryParameters['code'];
          if (code != null) {
            final String? state = queryParameters['state'];
            developer.log("Got successful on-login, authCode=$code, state=$state");
            _onAuthCodeReceived(code);
            final sourceWindow = event.source as html.WindowBase?;
            if (sourceWindow != null) {
              sourceWindow.close();
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _authorizer.removeListener(_onAuthorizerCredsChanged);
    if (kIsWeb) {
      developer.log("CredsModel: Removing window message listener");
      html.window.removeEventListener("message", _onWindowMessageEvent);
    }
    super.dispose();
  }
}
