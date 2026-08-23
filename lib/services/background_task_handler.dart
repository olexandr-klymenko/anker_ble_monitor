import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../data/ble/flutter_blue_anker_connection.dart';
import '../ipc/monitor_command.dart';
import '../ipc/telemetry_channel.dart';
import 'alarm_audio.dart';
import 'device_storage_service.dart';
import 'monitor_notifier.dart';
import 'monitor_service.dart';

/// Тонкий адаптер між `flutter_foreground_task` і [MonitorService]. Уся
/// оркестрація (BLE, тривога, звук, нотифікація) винесена в [MonitorService]
/// і його залежності — тут лише перекладання подій `TaskHandler` у виклики
/// сервісу та публікація телеметрії в UI-ізолят.
class AnkerBackgroundTaskHandler extends TaskHandler {
  late final MonitorService _monitorService;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    final deviceId = await DeviceStorageService.getSelectedDeviceId();
    final settings = await DeviceStorageService.getSettings();

    _monitorService = MonitorService(
      connection: FlutterBlueAnkerConnection(),
      audio: AudioPlayersAlarmAudio(),
      notifier: ForegroundTaskMonitorNotifier(),
      settings: settings,
    )..onTelemetry = TelemetryChannel.publish;

    _monitorService.start(deviceId);
  }

  @override
  void onReceiveData(Object data) {
    final command = MonitorCommand.fromJson(data);
    switch (command) {
      case SyncStateCommand():
        _monitorService.selectDevice(command.deviceId);
        _monitorService.updateSettings(command.settings);
      case SnoozeCommand():
        _monitorService.snooze();
      case null:
        return;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_snooze') {
      _monitorService.snooze();
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    _monitorService.tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _monitorService.dispose();
  }
}
