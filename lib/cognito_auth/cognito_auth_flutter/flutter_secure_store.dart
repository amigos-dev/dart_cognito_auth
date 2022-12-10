import "../cognito_auth_common/async_key_value_store.dart";
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlutterSecureStore implements AsyncKeyValueStore {
  final FlutterSecureStorage fss;

  const FlutterSecureStore.fromFlutterSecureStorage(this.fss);

  factory FlutterSecureStore({
    IOSOptions iOptions = IOSOptions.defaultOptions,
    AndroidOptions aOptions = AndroidOptions.defaultOptions,
    LinuxOptions lOptions = LinuxOptions.defaultOptions,
    WindowsOptions wOptions = WindowsOptions.defaultOptions,
    WebOptions webOptions = WebOptions.defaultOptions,
    MacOsOptions mOptions = MacOsOptions.defaultOptions,
  }) {
    final newFss = FlutterSecureStorage(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      wOptions: wOptions,
      webOptions: webOptions,
      mOptions: mOptions,
    );
    return FlutterSecureStore.fromFlutterSecureStorage(newFss);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
  }) async {
    return await fss.write(key: key, value: value);
  }

  @override
  Future<String?> read({
    required String key,
  }) async {
    return await fss.read(key: key);
  }

  @override
  Future<bool> containsKey({
    required String key,
  }) async {
    return await fss.containsKey(key: key);
  }

  @override
  Future<void> delete({
    required String key,
  }) async {
    return await fss.delete(key: key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return await fss.readAll();
  }

  @override
  Future<void> deleteAll() async {
    return await fss.deleteAll();
  }
}
