import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentityService {
  static const _deviceIdKey = 'device_id';
  static const _legacyFingerprintKey = 'device_fingerprint';
  static const _storage = FlutterSecureStorage();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getOrCreateDeviceId() async {
    final saved = await _storage.read(key: _deviceIdKey);
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }

    final legacy = await _storage.read(key: _legacyFingerprintKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _deviceIdKey, value: legacy);
      return legacy;
    }

    final deviceId = _createUuidV4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  Future<String> getDeviceFingerprint() async {
    final deviceId = await getOrCreateDeviceId();
    if (RegExp(r'^[a-f0-9]{64}$', caseSensitive: false).hasMatch(deviceId)) {
      return deviceId.toLowerCase();
    }
    return sha256.convert(utf8.encode(deviceId)).toString();
  }

  Future<String> getDeviceName() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return '${info.manufacturer} ${info.model}'.trim();
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return info.name.trim().isNotEmpty ? info.name.trim() : info.model;
    }
    return Platform.localHostname;
  }

  Future<String> getDeviceType() async {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  Future<String> getOperatingSystem() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return 'Android ${info.version.release}';
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return '${info.systemName} ${info.systemVersion}';
    }
    return Platform.operatingSystemVersion;
  }

  Future<Map<String, String>> getDevicePayload() async {
    final deviceId = await getOrCreateDeviceId();
    final deviceFingerprint = await getDeviceFingerprint();
    final deviceName = await getDeviceName();
    final deviceType = await getDeviceType();
    return {
      'deviceId': deviceId,
      'device_fingerprint': deviceFingerprint,
      'deviceName': deviceName,
      'device_name': deviceName,
      'deviceType': deviceType,
      'device_type': deviceType,
      'operatingSystem': await getOperatingSystem(),
    };
  }

  String _createUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
