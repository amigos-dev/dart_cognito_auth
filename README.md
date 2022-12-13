# dart_cognito_auth


## Build
For Linux:
```
flutter build -d Linux 
```

## Execution
```
flutter run lib/main.dart --dart-define CLIENT-SECRET=<secret string> --web-port=8501 -d Linux
```

bin/login_cli.dart is the commandline app that can be run with:

```
dart run bin/login_cli.dart -s <secret string>
```

## Prerequisites

## Linux prereq
```
sudo apt reinstall libsecret-tools libjsoncpp1 libsecret-1-0 libjsoncpp-dev libsecret-1-dev -y
```

Before native generated code modifications had been done in platform specific subdirectory cleanup and re-generating of platform code is done via:

```
rm -fr linux
flutter create --platforms=linux .
```

