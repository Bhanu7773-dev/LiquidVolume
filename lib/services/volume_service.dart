import 'package:flutter/services.dart';
import 'dart:async';

class VolumeService {
  static const _volumeChannel = EventChannel(
    'com.example.liquid_volume/volume',
  );
  static const _permissionChannel = MethodChannel(
    'com.example.liquid_volume/permissions',
  );

  static Stream<dynamic> get volumeEvents =>
      _volumeChannel.receiveBroadcastStream();

  static Future<bool> checkOverlayPermission() async {
    try {
      final bool hasPermission = await _permissionChannel.invokeMethod(
        'checkOverlayPermission',
      );
      return hasPermission;
    } on PlatformException catch (e) {
      print("Error checking overlay permission: ${e.message}");
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    await _permissionChannel.invokeMethod('requestOverlayPermission');
  }

  static Future<void> openAccessibilitySettings() async {
    await _permissionChannel.invokeMethod('openAccessibilitySettings');
  }

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool isEnabled = await _permissionChannel.invokeMethod(
        'isAccessibilityEnabled',
      );
      return isEnabled;
    } on PlatformException catch (e) {
      print("Error checking accessibility: ${e.message}");
      return false;
    }
  }

  static Future<double> getVolume() async {
    try {
      final double volume = await _permissionChannel.invokeMethod('getVolume');
      return volume;
    } catch (e) {
      return 0.5;
    }
  }

  static Future<void> setVolume(double volume) async {
    try {
      await _permissionChannel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      print("Error setting volume: $e");
    }
  }
}
