import 'package:flutter/material.dart';
//import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'dart:developer' as developer;
import 'creds.dart';
import 'api_info.dart';
import 'browser_auth.dart';
// import 'dart:io';
// import 'package:flutter_web_auth/flutter_web_auth.dart';

const defaultApiUriStr =
    'https://5i7ip3yxdb.execute-api.us-west-2.amazonaws.com/dev/';
const defaultPortStr = '8501';

const apiUriStr =
    String.fromEnvironment('API_URI', defaultValue: defaultApiUriStr);
const portStr = String.fromEnvironment('PORT', defaultValue: defaultPortStr);

final apiUri = Uri.parse(apiUriStr);
final port = int.parse(portStr);
const String? clientSecret = bool.hasEnvironment('CLIENT_SECRET')
    ? String.fromEnvironment('CLIENT_SECRET')
    : null;
late ApiInfo apiInfo;

void main() async {
  developer.log("main starting, uri=${Uri.base}, clientSecret=$clientSecret");
  if (clientSecret == null) {
    throw "CLIENT_SECRET is null";
  }
  apiInfo = await ApiInfo.retrieve(apiUri, clientSecret);
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) =>
          const MyHomePage(title: 'Flutter Demo Home Page'),
    ),
    GoRoute(
      path: "/on-login",
      builder: (context, state) =>
          const OnLoginPage(title: 'On-login redirect page'),
    )
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    developer.log('app building, uri=${Uri.base}');
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
    );
  }
}

class OnLoginPage extends StatelessWidget {
  /// Creates a [Page1Screen].
  const OnLoginPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to main page'),
              ),
            ],
          ),
        ),
      );

  final String title;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Creds? creds;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _onLogin(Creds creds) {
    developer.log('Login complete, creds=$creds');
  }

  void _onLoginError(Object? error, StackTrace stackTrace) {
    developer.log('Login failed, error=$error, stackTrace=$stackTrace');
  }

  void _doLogin() {
    browserAuthenticate(
      cognitoUri: apiInfo.cognitoUri,
      clientId: apiInfo.clientId,
      clientSecret: apiInfo.clientSecret,
    ).then(_onLogin).onError(_onLoginError);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    developer.log('home page state building, uri=${Uri.base}');
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            ElevatedButton(
              onPressed: () => _doLogin(),
              child: const Text('Login'),
            ),
            const Text(
              'The current URI is: ',
            ),
            Text(
              '${Uri.base}',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
/*
Future<void> _launchUrl() async {
  if (!await launchUrl(_url, webOnlyWindowName: '_self')) {
    throw 'Could not launch $_url';
  }
}
*/