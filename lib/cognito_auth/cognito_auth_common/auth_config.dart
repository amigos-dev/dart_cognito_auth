import 'package:meta/meta.dart';
import 'api_info.dart';

/// The default Oauth2 client secret--retrieved if available from environment
/// variable "CLIENT_SECRET".
const defaultClientSecret = bool.hasEnvironment('CLIENT_SECRET') ? String.fromEnvironment('CLIENT_SECRET') : null;

/// The default Oauth2 client ID--retrieved if available from environment
/// variable "CLIENT_ID".
const defaultClientId = bool.hasEnvironment('CLIENT_ID') ? String.fromEnvironment('CLIENT_ID') : null;

/// The default Oauth2 Cognito URI string--retrieved if available from environment
/// variable "COGNITO_URI".
const defaultCognitoUriStr = bool.hasEnvironment('COGNITO_URI') ? String.fromEnvironment('COGNITO_URI') : null;

/// The default Oauth2 Cognito URI--retrieved if available from environment
/// variable "COGNITO_URI".
final defaultCognitoUri = (defaultCognitoUriStr == null) ? null : Uri.parse(defaultCognitoUriStr!);

/// The default number of remaining seconds before the access token expires
/// at which it will be automatically refreshed before any API call.
const defaultRefreshGraceSeconds = 60 * 3;

/// The default API URI String--retrieved if available from environment variable "API_URI".
const defaultApiUriStr = bool.hasEnvironment('API_URI') ? String.fromEnvironment('API_URI') : null;
final defaultApiUri = (defaultApiUriStr == null) ? null : Uri.parse(defaultApiUriStr!);

/// The default key prefix within flutter_secure_storage at which a persistent refresh token will be stored
/// across sessions. This prefix will be concatenated with the clientID to allow for switchable clients.
const defaultSecureStorageRefreshTokenKeyPrefix = bool.hasEnvironment('SECURE_STORAGE_REFRESH_TOKEN_KEY_PREFIX')
    ? String.fromEnvironment('SECURE_STORAGE_REFRESH_TOKEN_KEY_PREFIX')
    : 'ssRefreshToken';

@immutable
class AuthConfig {
  /// The Oauth2 client ID string
  final String clientId;

  /// The Oauth2 Client secret, or null if there is no secret.
  final String? clientSecret;

  /// The Cognito user pool base URI; e.g., "https://amigos-users.auth.us-west-2.amazoncognito.com"
  final Uri cognitoUri;

  /// The list of scope names to be requested during authentication; e.g., ["openid", "email"],
  /// Or null to receive the default scopes (all available scopes).
  final List<String>? scopes;

  /// The number of remaining seconds before the access token expires
  /// at which it will be automatically refreshed before any API call. By
  /// default, defaultRefreshGraceSeconds is used.
  final int refreshGraceSeconds;

  /// The key prefix within flutter_secure_storage at which a persistent refresh token will be stored
  /// across sessions. This prefix will be concatenated with the clientID to allow for switchable clients.
  final String secureStorageRefreshTokenKeyPrefix;

  /// True if a persistent refresh token should be maintained in secure storage.
  final bool usePersistentRefreshToken;

  /// A const constructor with no default behavior. Internal only.
  const AuthConfig._bare({
    required this.cognitoUri,
    required this.clientId,
    this.clientSecret,
    this.scopes,
    required this.refreshGraceSeconds,
    required this.secureStorageRefreshTokenKeyPrefix,
    required this.usePersistentRefreshToken,
  });

  /// Construct a Cognito auth configuration object. Parameters:
  ///
  /// cognitoUri:
  ///     The Oauth2 Cognito URI; e.g., "https://amigos-users.auth.us-west-2.amazoncognito.com".
  ///     If null, retrieved from environment
  ///     variable "COGNITO_URI".
  ///
  /// clientId:
  ///     The Oauth2 client ID. If null, retrieved from environment
  ///     variable "CLIENT_ID".
  ///
  /// clientSecret:
  ///     The client secret. If null, retrieved if available from environment
  ///     variable "CLIENT_SECRET". If not provided in environment, then
  ///     no client secret is used.
  ///
  /// refreshGraceSeconds:
  ///    The number of remaining seconds before the access token expires
  ///    at which it will be automatically refreshed on demand. If null,
  ///    3 minutes is used.
  ///
  /// secureStorageRefreshTokenKeyPrefix:
  ///    The key prefix within flutter_secure_storage at which a persistent refresh token will be stored
  ///    across sessions. This prefix will be concatenated with the clientID to allow for switchable clients.
  ///    If null, retrieved if available from environment variable SECURE_STORAGE_REFRESH_TOKEN_KEY_PREFIX. If
  ///    not provided in the environment, then "ssRefreshToken" is used.
  ///
  /// usePersistentRefreshToken:
  ///    If true, a persistent refresh token will be maiontained in secure storage. Defaults to true.
  ///
  factory AuthConfig({
    Uri? cognitoUri,
    String? clientId,
    String? clientSecret,
    List<String>? scopes,
    int? refreshGraceSeconds,
    String? secureStorageRefreshTokenKeyPrefix,
    bool? usePersistentRefreshToken,
  }) {
    cognitoUri = cognitoUri ?? defaultCognitoUri;
    refreshGraceSeconds = refreshGraceSeconds ?? defaultRefreshGraceSeconds;
    clientId = clientId ?? defaultClientId;
    clientSecret = clientSecret ?? defaultClientSecret;
    secureStorageRefreshTokenKeyPrefix = secureStorageRefreshTokenKeyPrefix ?? defaultSecureStorageRefreshTokenKeyPrefix;
    usePersistentRefreshToken = usePersistentRefreshToken ?? true;
    final result = AuthConfig._bare(
      cognitoUri: cognitoUri!,
      clientId: clientId!,
      clientSecret: clientSecret,
      scopes: (scopes == null) ? null : List<String>.unmodifiable(scopes),
      refreshGraceSeconds: refreshGraceSeconds,
      secureStorageRefreshTokenKeyPrefix: secureStorageRefreshTokenKeyPrefix,
      usePersistentRefreshToken: usePersistentRefreshToken,
    );
    return result;
  }

  /// Construct a Cognito auth configuration object. Parameters:
  ///
  /// cognitoUri:
  ///     The Oauth2 Cognito URI; e.g., "https://amigos-users.auth.us-west-2.amazoncognito.com".
  ///     If null, retrieved from environment
  ///     variable "COGNITO_URI".
  ///
  /// clientId:
  ///     The Oauth2 client ID. If null, retrieved from environment
  ///     variable "CLIENT_ID".
  ///
  /// clientSecret:
  ///     The client secret. If null, retrieved if available from environment
  ///     variable "CLIENT_SECRET". If not provided in environment, then
  ///     no client secret is used.
  ///
  /// refreshGraceSeconds:
  ///    The number of remaining seconds before the access token expires
  ///    at which it will be automatically refreshed on demand. If null,
  ///    3 minutes is used.
  ///
  /// secureStorageRefreshTokenKeyPrefix:
  ///    The key prefix within flutter_secure_storage at which a persistent refresh token will be stored
  ///    across sessions. This prefix will be concatenated with the clientID to allow for switchable clients.
  ///    If null, retrieved if available from environment variable SECURE_STORAGE_REFRESH_TOKEN_KEY_PREFIX. If
  ///    not provided in the environment, then "ssRefreshToken" is used.
  ///
  /// usePersistentRefreshToken:
  ///    If true, a persistent refresh token will be maiontained in secure storage. Defaults to true.
  ///
  static Future<AuthConfig> fromApiInfo({
    Uri? apiUri,
    String? clientSecret,
    List<String>? scopes,
    int? refreshGraceSeconds,
    String? secureStorageRefreshTokenKeyPrefix,
    bool? usePersistentRefreshToken,
  }) async {
    apiUri = apiUri ?? defaultApiUri;
    clientSecret = clientSecret ?? defaultClientSecret;
    if (apiUri == null) {
      throw "An API_URI must be provided";
    }
    final apiInfo = await ApiInfo.retrieve(apiUri: apiUri, clientSecret: clientSecret);
    final result = AuthConfig(
      cognitoUri: apiInfo.cognitoUri,
      clientId: apiInfo.clientId,
      clientSecret: clientSecret,
      scopes: scopes,
      refreshGraceSeconds: refreshGraceSeconds,
      secureStorageRefreshTokenKeyPrefix: secureStorageRefreshTokenKeyPrefix,
      usePersistentRefreshToken: usePersistentRefreshToken,
    );
    return result;
  }

  Uri getTokenUri() {
    return cognitoUri.resolve('oauth2/token');
  }

  Uri getUserInfoUri() {
    return cognitoUri.resolve('oauth2/userInfo');
  }

  Uri getLoginBaseUri() {
    return cognitoUri.resolve('login');
  }

  Uri getLogoutBaseUri() {
    return cognitoUri.resolve('logout');
  }

  @override
  String toString() {
    return "AuthConfig(cognitoUri='$cognitoUri', clientId='$clientId', clientSecret='clientSecret', scopes=$scopes, refreshGraceSeconds=$refreshGraceSeconds)";
  }
}
