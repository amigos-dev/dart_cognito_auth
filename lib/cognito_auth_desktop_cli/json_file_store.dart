import "dart:io";
import "dart:convert";
import 'package:cognito_auth/cognito_auth_common/util.dart';
//import 'package:flutter/foundation.dart';
import 'package:quiver/collection.dart' show mapsEqual;

import '../cognito_auth_common/async_key_value_store.dart';
import 'package:mutex/mutex.dart';
import 'dart:developer' as developer;

/// An AsyncKeyValueStore built on a single JSON file
class JsonFileStore implements AsyncKeyValueStore {
  final m = Mutex();
  final bool isExclusive;
  final bool createIfMissing;
  final bool createParentDirs;
  late File _file;
  late bool _needCreateCheck;
  Map<String, String>? _cached; // modification is disabled

  JsonFileStore({
    required String pathname,
    this.isExclusive = true,
    this.createIfMissing = true,
    this.createParentDirs = true,
  }) {
    _file = File(pathname);
    _needCreateCheck = createIfMissing;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
  }) async {
    await m.protect<void>(() async {
      // NOTE: even if isExclusive is false, there is a window here between _readAllLocked
      //       and _writeAllLocked when an update by another process may be overwritten.
      var values = await _readAllLocked();
      bool needUpdate = false;
      if (value == null) {
        if (values.containsKey(key)) {
          values = Map<String, String>.from(values);
          values.remove(key);
          needUpdate = true;
        }
      } else {
        if (values[key] != value) {
          values = Map<String, String>.from(values);
          values[key] = value;
          needUpdate = true;
        }
      }
      if (needUpdate) {
        await _writeAllLocked(values);
      }
    });
  }

  @override
  Future<String?> read({
    required String key,
  }) async {
    final values = await readAll();
    final result = values[key];
    return result;
  }

  @override
  Future<bool> containsKey({
    required String key,
  }) async {
    final values = await readAll();
    return values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
  }) async {
    await m.protect<void>(() async {
      // NOTE: even if isExclusive is false, there is a window here between _readAllLocked
      //       and _writeAllLocked when an update by another process may be overwritten.
      final values = await _readAllLocked();
      if (values.containsKey(key)) {
        final newValues = Map<String, String>.from(values);
        newValues.remove(key);
        await _writeAllLocked(newValues);
      }
    });
  }

  Future<Map<String, String>> _readAllLocked() async {
    if (!isExclusive || _cached == null) {
      if (_needCreateCheck) {
        if (!await _file.exists()) {
          await _file.create(recursive: createParentDirs);
        }
        _needCreateCheck = false;
      }
      final resultStr = await _file.readAsString();
      final Map<String, dynamic> resultDyn = resultStr == "" ? {} : jsonDecode(resultStr);
      _cached = Map.unmodifiable(resultDyn.map((key, value) => MapEntry(key, value.toString())));
    }
    return _cached!;
  }

  @override
  Future<Map<String, String>> readAll() async {
    final result = await m.protect<Map<String, String>>(() async {
      return await _readAllLocked();
    });
    return result;
  }

  Future<void> _writeAllLocked(Map<String, String> values) async {
    if (_cached == null) {
      // ensure file is created, etc according to policy. After the first
      // read or write, this step will be skipped.
      await _readAllLocked();
    }
    if (!isExclusive || _cached == null || !mapsEqual(values, _cached)) {
      final newMap = Map<String, String>.from(values);
      final outStr = jsonEncode(newMap);
      try {
        await _file.writeAsString(outStr, flush: true);
      } catch (e, stackTrace) {
        developer.log("Unable to write to json file key value store: $e: pathname: ${_file.path}, stackTrace: $stackTrace");
      }
      _needCreateCheck = false;
      _cached = newMap;
    }
  }

  Future<void> writeAll(Map<String, String> values) async {
    await m.protect<void>(() async {
      await _writeAllLocked(values);
    });
  }

  @override
  Future<void> deleteAll() async {
    return await writeAll({});
  }
}
