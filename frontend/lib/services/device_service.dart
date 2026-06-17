import 'device_identity_service.dart';

export 'device_identity_service.dart';

/// Backward-compatible wrapper around [DeviceIdentityService].
class DeviceService {
  final DeviceIdentityService _identity = DeviceIdentityService();

  Future<String> getDeviceFingerprint() => _identity.getDeviceFingerprint();

  Future<String> getOrCreateDeviceId() => _identity.getOrCreateDeviceId();
}
