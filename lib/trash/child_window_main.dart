import 'package:flutter/material.dart';
import "package:universal_html/html.dart" as html;
import 'dart:developer' as developer;
//import 'package:flutter_web_plugins/url_strategy.dart';
//import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  developer.log("main(), Uri.base=${Uri.base}");
  // if (kIsWeb) {
  //   usePathUrlStrategy();
  // }
  developer.log("main(), Uri.base=${Uri.base}");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String? authCode;

  @override
  void initState() {
    super.initState();

    html.window.addEventListener("message", (event) {
      if (event is html.MessageEvent) {
        //final messageEvent = event as html.MessageEvent;
        final data = Map<String, dynamic>.from(event.data);
        developer.log("Got message-event, event data=$data");
        if (data['name'] == 'on-login') {
          String queryString = data['query-string'] ?? '';
          if (queryString.startsWith('?')) {
            queryString = queryString.substring(1);
          }

          developer
              .log("Got on-login message event, query-string=$queryString");
          final queryParameters =
              Uri.base.replace(query: queryString).queryParameters;
          developer.log(
              "Got on-login message event, query-parameters=$queryParameters");
          final String? code = queryParameters['code'];
          if (code != null) {
            final String? state = queryParameters['state'];
            developer
                .log("Got successful on-login, authCode=$code, state=$state");
            authCode = code;
            final sourceWindow = event.source as html.WindowBase?;
            if (sourceWindow != null) {
              sourceWindow.close();
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    developer.log("MyApp.build(), Uri.base=${Uri.base}");
    return MaterialApp(
      title: "Hello World",
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '/';
        final uri = Uri.parse(routeName);
        final queryParameters = uri.queryParameters;
        final routePath = uri.path;

        if (routePath == '/') {
          final String? authCode = queryParameters['code'];
          if (authCode != null) {
            return MaterialPageRoute(
                builder: (context) => OnLoginPage(authCode: authCode));
          }
          return MaterialPageRoute(builder: (context) => const HomePage());
        }

        return MaterialPageRoute(
            builder: (context) => UnknownPage(routeName: routeName));
      },
    );
  }
}

class UnknownPage extends StatelessWidget {
  final String routeName;

  const UnknownPage({required this.routeName, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('Unknown route, $routeName'),
      ),
    );
  }
}

class OnLoginPage extends StatelessWidget {
  final String authCode;

  const OnLoginPage({required this.authCode, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('Login complete, auth code=$authCode'),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    developer.log("HomePage.build(), Uri.base=${Uri.base}");
    return Scaffold(
        appBar: AppBar(
          title: const Text("Open External Link"),
          backgroundColor: Colors.redAccent,
        ),
        body: Column(
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  final redirectUri =
                      Uri.base.removeFragment().resolve('on-login.html');
                  final uri = Uri.parse(
                          'https://amigos-users.auth.us-west-2.amazoncognito.com/authorize')
                      .replace(queryParameters: {
                    "client_id": "260fm8860vbaltkflng33m75bv",
                    "response_type": "code",
                    "redirect_uri": redirectUri.toString(),
                    "scope": "email openid",
                  });
                  /*
                  final uri = redirectUri.replace(queryParameters: {'code': 'foobar'});
                  */
                  html.window.open(uri.toString(), "_blank", 'location=yes');
                },
                child: const Text("Login"),
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  final redirectUri =
                      Uri.base.removeFragment().resolve('on-login.html');
                  final uri = Uri.parse(
                          'https://amigos-users.auth.us-west-2.amazoncognito.com/logout')
                      .replace(queryParameters: {
                    "client_id": "260fm8860vbaltkflng33m75bv",
                    "response_type": "code",
                    "redirect_uri": redirectUri.toString(),
                    "scope": "email openid",
                    "state": "foo-state",
                  });
                  /*
                  final uri = redirectUri.replace(queryParameters: {'code': 'foobar'});
                  */
                  html.window.open(uri.toString(), "_blank", 'location=yes');
                },
                child: const Text("Logout"),
              ),
            ),
            const Center(
              child: Text("authCode=TBD"),
            ),
          ],
        ));
  }
}
