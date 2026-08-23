import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anker_ble_monitor/domain/models/monitor_settings.dart';
import 'package:anker_ble_monitor/services/device_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Ініціалізація фейкових SharedPreferences у пам'яті перед кожним тестом
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceStorageService Tests', () {
    test('Should return default settings when nothing is saved', () async {
      final settings = await DeviceStorageService.getSettings();

      expect(settings, equals(MonitorSettings.defaults));
    });

    test('Should save and retrieve custom threshold settings correctly',
        () async {
      await DeviceStorageService.saveSettings(const MonitorSettings(
        lowThreshold: 20,
        fullThreshold: 90,
        snoozeMinutes: 5,
      ));

      final settings = await DeviceStorageService.getSettings();

      expect(settings.lowThreshold, equals(20));
      expect(settings.fullThreshold, equals(90));
      expect(settings.snoozeMinutes, equals(5));
    });

    test('Should save, retrieve, and delete devices correctly', () async {
      final device1 =
          SavedDevice(id: 'AA:BB:CC:11:22:33', originalName: 'Anker 767');
      final device2 = SavedDevice(
          id: 'DD:EE:FF:44:55:66',
          originalName: 'Anker PowerHouse',
          customName: 'Моя Станція');

      // 1. Збереження
      await DeviceStorageService.saveDevice(device1);
      await DeviceStorageService.saveDevice(device2);

      var devices = await DeviceStorageService.getSavedDevices();
      expect(devices.length, equals(2));
      expect(devices.first.displayName, equals('Anker 767'));
      expect(devices.last.displayName, equals('Моя Станція'));

      // 2. Видалення
      await DeviceStorageService.deleteDevice('AA:BB:CC:11:22:33');
      devices = await DeviceStorageService.getSavedDevices();

      expect(devices.length, equals(1));
      expect(devices.first.id, equals('DD:EE:FF:44:55:66'));
    });

    test('Should manage selected device ID', () async {
      const deviceId = 'AA:BB:CC:11:22:33';

      expect(await DeviceStorageService.getSelectedDeviceId(), isNull);

      await DeviceStorageService.setSelectedDeviceId(deviceId);
      expect(
          await DeviceStorageService.getSelectedDeviceId(), equals(deviceId));
    });
  });
}
