import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PermissionService {
  /// Запит усіх необхідних дозволів для BLE, фонового сервісу та сповіщень
  static Future<bool> requestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. Запит дозволів на Bluetooth та сповіщення
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();

    // Перевірка чи надані основні дозволи
    bool bluetoothGranted = 
        (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
        (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

    bool locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    // Якщо це Android 12+ (API 31+), то геолокація для BLE вже не є обов'язковою, якщо є bluetoothScan
    bool isBleReady = bluetoothGranted || locationGranted;

    if (!isBleReady) {
      return false;
    }

    // 2. Запит на вимкнення оптимізації батареї (щоб Android не присипляв сервіс у фоні)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return true;
  }

/// Перевірка чи увімкнений Bluetooth
static Future<bool> isBluetoothEnabled() async {
  BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
  return state == BluetoothAdapterState.on;
}
}