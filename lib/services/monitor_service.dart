import 'dart:async';
import '../data/ble/anker_connection.dart';
import '../domain/alarm_controller.dart';
import '../domain/models/monitor_settings.dart';
import '../domain/monitor_notification_builder.dart';
import '../models/anker_telemetry.dart';
import 'alarm_audio.dart';
import 'monitor_notifier.dart';
import 'telemetry_parser.dart';

/// Оркеструє один цикл моніторингу: BLE-телеметрія -> [AlarmController] ->
/// звук + нотифікація -> публікація в UI. Не залежить від `TaskHandler`,
/// `flutter_blue_plus` чи `flutter_foreground_task` напряму — лише від
/// абстракцій ([AnkerConnection], [AlarmAudio], [MonitorNotifier]), тому
/// весь сценарій ("телеметрія 12% без зарядки -> тривога -> пауза -> тиша")
/// перевіряється юніт-тестом із фейками, без реальної станції.
class MonitorService {
  final AnkerConnection connection;
  final AlarmAudio audio;
  final MonitorNotifier notifier;
  final AlarmController _alarmController;

  MonitorSettings _settings;
  String? _targetDeviceId;
  int _lastSoc = -1;
  bool _lastIsCharging = false;

  StreamSubscription<TelemetryParseResult>? _telemetrySub;
  StreamSubscription<bool>? _connectionSub;

  /// Викликається щоразу, коли варто оновити UI-ізолят свіжою телеметрією.
  void Function(AnkerTelemetry telemetry)? onTelemetry;

  MonitorService({
    required this.connection,
    required this.audio,
    required this.notifier,
    MonitorSettings settings = MonitorSettings.defaults,
    AlarmController? alarmController,
  })  : _settings = settings,
        _alarmController = alarmController ?? AlarmController();

  MonitorSettings get settings => _settings;

  /// Починає моніторинг: підписується на потоки [connection] і, якщо є
  /// збережений пристрій, одразу запускає підключення.
  void start(String? deviceId) {
    _targetDeviceId = deviceId;
    _telemetrySub = connection.telemetry.listen(_onTelemetry);
    _connectionSub = connection.connectionState.listen(_onConnectionStateChanged);

    if (deviceId != null && deviceId.isNotEmpty) {
      connection.connect(deviceId);
    }
  }

  /// Періодичний тік (раніше `onRepeatEvent`): підтримує сесію активною
  /// keep-alive пакетом, або перепідключається, якщо зв'язку немає.
  void tick() {
    if (connection.isConnected) {
      connection.sendKeepAlive();
    } else if (_targetDeviceId != null && _targetDeviceId!.isNotEmpty) {
      connection.connect(_targetDeviceId!);
    }
  }

  /// Змінює пороги/паузу і, якщо вже є телеметрія, одразу перераховує
  /// тривогу під нові значення (ідемпотентно — [AlarmController] не
  /// перезапускає вже активну тривогу).
  void updateSettings(MonitorSettings settings) {
    _settings = settings;
    if (_lastSoc >= 0) {
      _checkAlarm(_lastSoc, _lastIsCharging);
    }
  }

  /// Перемикає цільовий пристрій: розриває поточне з'єднання і підключається
  /// до нового. Не робить нічого, якщо `deviceId` не змінився.
  Future<void> selectDevice(String deviceId) async {
    if (_targetDeviceId == deviceId) return;
    _targetDeviceId = deviceId;
    await connection.disconnect();
    if (deviceId.isNotEmpty) {
      await connection.connect(deviceId);
    }
  }

  /// Ручна призупинка тривоги (кнопка в нотифікації чи в UI-застосунку).
  void snooze() {
    final now = DateTime.now();
    final snoozeResult =
        _alarmController.activateSnooze(Duration(minutes: _settings.snoozeMinutes), now: now);
    _applyAudio(snoozeResult.audioAction);

    if (_lastSoc < 0) return;
    final evaluation = _alarmController.evaluate(
      soc: _lastSoc,
      isCharging: _lastIsCharging,
      lowThreshold: _settings.lowThreshold,
      fullThreshold: _settings.fullThreshold,
      now: now,
    );
    notifier.show(MonitorNotificationBuilder.build(
      evaluation: evaluation,
      settings: _settings,
      soc: _lastSoc,
      isCharging: _lastIsCharging,
    ));
  }

  void _onTelemetry(TelemetryParseResult result) {
    _lastSoc = result.soc;
    _lastIsCharging = result.isCharging;
    final evaluation = _checkAlarm(_lastSoc, _lastIsCharging);

    onTelemetry?.call(AnkerTelemetry(
      isAlarmRinging: evaluation.isAlarmRinging,
      soc: _lastSoc,
      isCharging: _lastIsCharging,
    ));
  }

  void _onConnectionStateChanged(bool connected) {
    if (!connected) {
      notifier.showConnectionLost();
    }
  }

  AlarmEvaluation _checkAlarm(int soc, bool isCharging) {
    final evaluation = _alarmController.evaluate(
      soc: soc,
      isCharging: isCharging,
      lowThreshold: _settings.lowThreshold,
      fullThreshold: _settings.fullThreshold,
    );
    _applyAudio(evaluation.audioAction);
    notifier.show(MonitorNotificationBuilder.build(
      evaluation: evaluation,
      settings: _settings,
      soc: soc,
      isCharging: isCharging,
    ));
    return evaluation;
  }

  void _applyAudio(AlarmAudioAction action) {
    switch (action) {
      case AlarmAudioAction.none:
        return;
      case AlarmAudioAction.stop:
        audio.stop();
        return;
      case AlarmAudioAction.playLow:
        audio.playLoop('audio/alarm_clock.ogg');
        return;
      case AlarmAudioAction.playFull:
        audio.playLoop('audio/full_charge.ogg');
        return;
    }
  }

  Future<void> dispose() async {
    await _telemetrySub?.cancel();
    await _connectionSub?.cancel();
    await connection.dispose();
    await audio.dispose();
  }
}
