import 'package:provider/provider.dart';
import '../cognito_auth_common/cognito_auth_common.dart';
import 'package:flutter/material.dart';
import "creds_model.dart";

class CognitoAuthenticator extends StatefulWidget {
  final AuthConfig authConfig;
  final Widget? child;
  final Uri? loginCallbackUri;
  final String? initialRefreshToken;

  const CognitoAuthenticator({
    super.key,
    required this.authConfig,
    this.child,
    this.loginCallbackUri,
    this.initialRefreshToken,
  });

  @override
  State<CognitoAuthenticator> createState() => _CognitoAuthenticatorState();
}

class _CognitoAuthenticatorState extends State<CognitoAuthenticator> {
  Widget? get child => widget.child;
  late CredsModel credsModel;

  @override
  void initState() {
    super.initState();
    credsModel =
        CredsModel(authConfig: widget.authConfig, loginCallbackUri: widget.loginCallbackUri, initialRefreshToken: widget.initialRefreshToken);
  }

  @override
  void dispose() {
    credsModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(value: credsModel, child: child);
  }
}
