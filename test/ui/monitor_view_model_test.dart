import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anker_ble_monitor/domain/models/monitor_settings.dart';
import 'package:anker_ble_monitor/ipc/monitor_command.dart';
import 'package:anker_ble_monitor/services/device_storage_service.dart';
import 'package:anker_ble_monitor/ui/monitor_view_model.dart';

/// [MonitorViewModel] делегує підключення/запуск сервісу до
/// `flutter_foreground_task`, а той спілкується з платформою через
/// `MethodChannel('flutter_foreground_task/methods')`. У юніт-тесті немає
/// реальної платформи, тож підміняємо канал самі — фіксуємо виклики й
/// віддаємо канонічні відповіді ('isRunningService' -> [_runningServiceResponse]
/// і т.д.), як радить сам пакет (`skipServiceResponseCheck`,
/// `@visibleForTesting`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_foreground_task/methods');
  final calls = <MethodCall>[];
  bool runningServiceResponse = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    runningServiceResponse = false;
    FlutterForegroundTask.skipServiceResponseCheck = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isRunningService') return runningServiceResponse;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('init() підвантажує пристрій, налаштування й статус сервісу зі сховища',
      () async {
    await DeviceStorageService.saveDevice(
        SavedDevice(id: 'AA:BB:CC:11:22:33', originalName: 'Anker'));
    await DeviceStorageService.setSelectedDeviceId('AA:BB:CC:11:22:33');
    await DeviceStorageService.saveSettings(const MonitorSettings(
        lowThreshold: 20, fullThreshold: 95, snoozeMinutes: 4));

    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);

    expect(vm.selectedDevice?.id, 'AA:BB:CC:11:22:33');
    expect(vm.settings.lowThreshold, 20);
    expect(vm.settings.fullThreshold, 95);
    expect(vm.isServiceRunning, isFalse);
  });

  test('init() без збереженого пристрою -> selectedDevice=null', () async {
    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);

    expect(vm.selectedDevice, isNull);
  });

  test('updateSettings() зберігає в сховище й надсилає SyncStateCommand у '
      'фоновий ізолят', () async {
    await DeviceStorageService.saveDevice(
        SavedDevice(id: 'AA:BB:CC:11:22:33', originalName: 'Anker'));
    await DeviceStorageService.setSelectedDeviceId('AA:BB:CC:11:22:33');

    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);
    calls.clear();

    await vm.updateSettings(
        const MonitorSettings(lowThreshold: 25, fullThreshold: 92, snoozeMinutes: 5));

    expect(vm.settings.lowThreshold, 25);
    final persisted = await DeviceStorageService.getSettings();
    expect(persisted.lowThreshold, 25);

    final sendDataCall = calls.singleWhere((c) => c.method == 'sendData');
    final command = MonitorCommand.fromJson(sendDataCall.arguments);
    expect(command, isA<SyncStateCommand>());
    expect((command as SyncStateCommand).settings.lowThreshold, 25);
    expect(command.deviceId, 'AA:BB:CC:11:22:33');
  });

  test('startService() нічого не робить, якщо пристрій не обрано', () async {
    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);
    calls.clear();

    await vm.startService(() {});

    expect(vm.isServiceRunning, isFalse);
    expect(calls, isEmpty);
  });

  test('startService() з обраним пристроєм запускає сервіс і синхронізує '
      'налаштування', () async {
    await DeviceStorageService.saveDevice(
        SavedDevice(id: 'AA:BB:CC:11:22:33', originalName: 'Anker'));
    await DeviceStorageService.setSelectedDeviceId('AA:BB:CC:11:22:33');

    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);
    calls.clear();

    await vm.startService(() {});

    expect(vm.isServiceRunning, isTrue);
    expect(calls.any((c) => c.method == 'startService'), isTrue);
    expect(calls.any((c) => c.method == 'sendData'), isTrue);
  });

  test('stopService() зупиняє сервіс і скидає телеметрію/тривогу', () async {
    await DeviceStorageService.saveDevice(
        SavedDevice(id: 'AA:BB:CC:11:22:33', originalName: 'Anker'));
    await DeviceStorageService.setSelectedDeviceId('AA:BB:CC:11:22:33');

    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);
    await vm.startService(() {});
    runningServiceResponse = true; // сервіс тепер "запущений" з т.з. платформи

    await vm.stopService();

    expect(vm.isServiceRunning, isFalse);
    expect(vm.isAlarmRinging, isFalse);
    expect(vm.latestTelemetry, isNull);
  });

  test('snooze() скидає isAlarmRinging і надсилає SnoozeCommand', () async {
    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);
    vm.isAlarmRinging = true;
    calls.clear();

    vm.snooze();

    expect(vm.isAlarmRinging, isFalse);
    final sendDataCall = calls.single;
    expect(sendDataCall.method, 'sendData');
    expect(MonitorCommand.fromJson(sendDataCall.arguments),
        equals(const SnoozeCommand()));
  });

  test('refreshSelectedDevice() перечитує обраний пристрій зі сховища',
      () async {
    final vm = MonitorViewModel();
    await vm.init();
    addTearDown(vm.dispose);
    expect(vm.selectedDevice, isNull);

    await DeviceStorageService.saveDevice(
        SavedDevice(id: 'AA:BB:CC:11:22:33', originalName: 'Anker'));
    await DeviceStorageService.setSelectedDeviceId('AA:BB:CC:11:22:33');

    await vm.refreshSelectedDevice();

    expect(vm.selectedDevice?.id, 'AA:BB:CC:11:22:33');
  });
}
