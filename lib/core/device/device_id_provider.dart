import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A stable, per-install identifier -- not a hardware ID (Android/iOS both
/// block apps from reading the real MAC address), just an app-generated
/// value persisted in secure storage on first use. Backs the account's
/// device-limit enforcement (see sealanka-be's device_id on RefreshToken).
class DeviceIdProvider {
  static const _key = 'device_id';
  final FlutterSecureStorage _secureStorage;
  String? _cached;

  DeviceIdProvider(this._secureStorage);

  Future<String> getOrCreate() async {
    if (_cached != null) return _cached!;
    var id = await _secureStorage.read(key: _key);
    if (id == null) {
      id = _generate();
      await _secureStorage.write(key: _key, value: id);
    }
    _cached = id;
    return id;
  }

  String _generate() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
