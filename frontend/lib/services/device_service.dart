import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceService {
  static const _fingerprintKey = 'device_fingerprint';
  static const _storage = FlutterSecureStorage();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getDeviceFingerprint() async {
    final saved = await _storage.read(key: _fingerprintKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final platformIdentity = await _readPlatformIdentity();
    final installationEntropy = _createSecureEntropy();
    final fingerprint = sha256
        .convert(utf8.encode('$platformIdentity|$installationEntropy'))
        .toString();

    await _storage.write(key: _fingerprintKey, value: fingerprint);
    return fingerprint;
  }

  Future<String> _readPlatformIdentity() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return [
        'android',
        info.id,
        info.fingerprint,
        info.manufacturer,
        info.model,
      ].join('|');
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return [
        'ios',
        info.identifierForVendor ?? 'unknown',
        info.model,
        info.systemVersion,
      ].join('|');
    }

    return '${Platform.operatingSystem}|${Platform.localHostname}';
  }

  String _createSecureEntropy() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
