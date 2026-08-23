import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../domain/models/monitor_settings.dart';
import '../ipc/monitor_command.dart';
import '../ipc/telemetry_channel.dart';
import '../models/anker_telemetry.dart';
import '../services/device_storage_service.dart';
import '../services/permission_service.dart';

/// Стан екрана моніторингу — без жодного `BuildContext`/`Navigator`, тому
/// тестується `flutter_test` без побудови віджетів. Навігація (відкриття
/// екрана вибору пристрою чи налаштувань) лишається за [HomeScreen] —
/// [MonitorViewModel] лише зберігає й публікує дані, на основі яких View
/// вирішує, що показати.
class MonitorViewModel extends ChangeNotifier {
  MonitorSettings settings = MonitorSettings.defaults;
  bool isServiceRunning = false;
  bool isAlarmRinging = false;
  SavedDevice? selectedDevice;
  AnkerTelemetry? latestTelemetry;

  TelemetryChannel? _telemetryChannel;
  StreamSubscription<AnkerTelemetry>? _telemetrySubscription;

  /// Завантажує збережений стан і підписується на телеметрію. Виклики
  /// сховища виконуються паралельно (як і раніше — три незалежні `await` в
  /// `initState`), але тепер результат публікується одним [notifyListeners]
  /// замість трьох окремих `setState`.
  Future<void> init() async {
    _initForegroundTask();

    await Future.wait([
      _loadSettings(),
      _loadSelectedDevice(),
      _loadServiceStatus(),
    ]);

    _telemetryChannel = TelemetryChannel.subscribe();
    _telemetrySubscription = _telemetryChannel!.stream.listen((telemetry) {
      latestTelemetry = telemetry;
      isAlarmRinging = telemetry.isAlarmRinging;
      notifyListeners();
    });

    notifyListeners();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'anker_ble_channel',
        channelName: 'Anker BLE Monitor',
        channelDescription: 'Стеження за станом заряду Anker у фоні',
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(3000),
        autoRunOnBoot: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _loadSettings() async {
    settings = await DeviceStorageService.getSettings();
  }

  Future<void> _loadServiceStatus() async {
    isServiceRunning = await FlutterForegroundTask.isRunningService;
  }

  Future<void> _loadSelectedDevice() async {
    final selectedId = await DeviceStorageService.getSelectedDeviceId();
    final devices = await DeviceStorageService.getSavedDevices();
    selectedDevice =
        (selectedId != null && devices.any((d) => d.id == selectedId))
            ? devices.firstWhere((d) => d.id == selectedId)
            : null;
  }

  /// Перечитує обраний пристрій зі сховища (після повернення з екрана
  /// вибору пристрою) і синхронізує фоновий сервіс.
  Future<void> refreshSelectedDevice() async {
    await _loadSelectedDevice();
    _sendStateToTask();
    notifyListeners();
  }

  Future<void> updateSettings(MonitorSettings newSettings) async {
    settings = newSettings;
    await DeviceStorageService.saveSettings(settings);
    _sendStateToTask();
    notifyListeners();
  }

  Future<bool> requestPermissions() => PermissionService.requestAllPermissions();

  Future<void> startService(void Function() startBackgroundCallback) async {
    if (selectedDevice == null) return;

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 257,
        notificationTitle: 'Anker Monitor',
        notificationText: 'Підключення до станції...',
        callback: startBackgroundCallback,
      );
    }

    isServiceRunning = true;
    _sendStateToTask();
    notifyListeners();
  }

  Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
    isServiceRunning = false;
    isAlarmRinging = false;
    latestTelemetry = null;
    notifyListeners();
  }

  void snooze() {
    FlutterForegroundTask.sendDataToTask(const SnoozeCommand().toJson());
    isAlarmRinging = false;
    notifyListeners();
  }

  void _sendStateToTask() {
    final device = selectedDevice;
    if (device == null) return;
    FlutterForegroundTask.sendDataToTask(
      SyncStateCommand(deviceId: device.id, settings: settings).toJson(),
    );
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _telemetryChannel?.close();
    super.dispose();
  }
}
