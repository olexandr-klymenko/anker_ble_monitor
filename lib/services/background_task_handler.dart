import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../events/isolate_pubsub.dart';
import '../models/anker_telemetry.dart';
import 'device_storage_service.dart';
import 'telemetry_parser.dart';

class AnkerBackgroundTaskHandler extends TaskHandler {
  int _currentThreshold = 15;
  int _fullThreshold = 100;
  int _snoozeDurationMinutes = 3;
  DateTime? _snoozeUntil;

  String? _targetDeviceId;
  int _lastSoc = -1;
  bool _lastIsCharging = false;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLowAlarmActive = false;
  bool _isFullAlarmActive = false;
  bool _isConnecting = false;

  final List<int> _ankerAuthPayload = [
    0x08,
    0xEE,
    0x00,
    0x00,
    0x00,
    0x01,
    0x01,
    0x0A,
    0x00,
    0x02
  ];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    _targetDeviceId = await DeviceStorageService.getSelectedDeviceId();

    final settings = await DeviceStorageService.getSettings();
    _currentThreshold = settings['lowThreshold']!;
    _fullThreshold = settings['fullThreshold']!;
    _snoozeDurationMinutes = settings['snoozeMinutes']!;

    if (_targetDeviceId != null && _targetDeviceId!.isNotEmpty) {
      _connectDirectly(_targetDeviceId!);
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      bool settingsChanged = false;

      if (data.containsKey('deviceId') && data['deviceId'] is String) {
        String newId = data['deviceId'] as String;
        if (_targetDeviceId != newId) {
          _targetDeviceId = newId;
          _disconnectAndReconnect();
        }
      }
      if (data.containsKey('threshold') && data['threshold'] is int) {
        _currentThreshold = data['threshold'] as int;
        settingsChanged = true;
      }
      if (data.containsKey('fullThreshold') && data['fullThreshold'] is int) {
        _fullThreshold = data['fullThreshold'] as int;
        settingsChanged = true;
      }
      if (data.containsKey('snoozeDuration') && data['snoozeDuration'] is int) {
        _snoozeDurationMinutes = data['snoozeDuration'] as int;
        settingsChanged = true;
      }
      if (data.containsKey('action') && data['action'] == 'snooze') {
        _activateSnooze();
      }

      if (settingsChanged && _lastSoc >= 0) {
        _checkAlarm(_lastSoc, _lastIsCharging);
      }
    }
  }

  Future<void> _disconnectAndReconnect() async {
    _telemetrySub?.cancel();
    _connStateSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _writeChar = null;

    if (_targetDeviceId != null && _targetDeviceId!.isNotEmpty) {
      _connectDirectly(_targetDeviceId!);
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_snooze') {
      _activateSnooze();
    }
  }

  void _activateSnooze() async {
    _snoozeUntil =
        DateTime.now().add(Duration(minutes: _snoozeDurationMinutes));
    _stopAlarm();
    _updateNotificationStatus(_lastSoc, _lastIsCharging);
  }

  bool _isSnoozed() {
    if (_snoozeUntil == null) return false;
    if (DateTime.now().isAfter(_snoozeUntil!)) {
      _snoozeUntil = null;
      return false;
    }
    return true;
  }

  void _updateNotificationStatus(int soc, bool isCharging) {
    if (_isLowAlarmActive || _isFullAlarmActive) return;

    bool isLowAlarmCondition = soc <= _currentThreshold && !isCharging;
    bool isFullAlarmCondition = soc >= _fullThreshold && isCharging;
    bool isAlarmCondition = isLowAlarmCondition || isFullAlarmCondition;

    if (isAlarmCondition && _isSnoozed()) {
      int remainingMin = _snoozeUntil!.difference(DateTime.now()).inMinutes + 1;
      String statusText = isCharging
          ? '⚡ Досягнуто $_fullThreshold%. Звук заглушено на $remainingMin хв'
          : '⚠️ Низький заряд (<= $_currentThreshold%). Звук заглушено на $remainingMin хв';

      FlutterForegroundTask.updateService(
        notificationTitle: 'Anker: $soc% (🔕 Пауза)',
        notificationText: statusText,
        notificationButtons: [],
      );
    } else if (isCharging) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Anker: $soc% (⚡ Заряджається)',
        notificationText: 'Живлення підключено.',
        notificationButtons: [],
      );
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Anker: $soc%',
        notificationText: 'Заряд під контролем (поріг: $_currentThreshold%)',
        notificationButtons: [],
      );
    }
  }

  Future<void> _connectDirectly(String deviceId) async {
    if (_device != null || _isConnecting) return;
    _isConnecting = true;

    try {
      BluetoothDevice dev = BluetoothDevice.fromId(deviceId);
      _device = dev;

      await dev.connect(
        license: License.nonprofit,
        autoConnect: false,
        timeout: const Duration(seconds: 7),
      );

      _connStateSub?.cancel();
      _connStateSub = dev.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _device = null;
          _writeChar = null;
          FlutterForegroundTask.updateService(
            notificationTitle: 'Anker Monitor',
            notificationText: 'Зв\'язок втрачено. Очікування...',
            notificationButtons: [],
          );
        }
      });

      List<BluetoothService> services = await dev.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          String uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains("7777")) _writeChar = c;
          if (uuid.contains("8888")) _subscribeTelemetry(c);
        }
      }
    } catch (e) {
      _device = null;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _subscribeTelemetry(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    _telemetrySub?.cancel();
    _telemetrySub = c.lastValueStream.listen((bytes) {
      final parseResult = TelemetryParser.parse(bytes);
      if (parseResult != null) {
        _lastSoc = parseResult.soc;
        _lastIsCharging = parseResult.isCharging;

        _checkAlarm(_lastSoc, _lastIsCharging);

        bool isAlarmRinging =
            (_isLowAlarmActive || _isFullAlarmActive) && !_isSnoozed();

        IsolatePubSub.publish(
          AnkerTelemetry(
            isAlarmRinging: isAlarmRinging,
            soc: _lastSoc,
            acInWatts: 0,
            isCharging: _lastIsCharging,
          ),
        );

        _updateNotificationStatus(_lastSoc, _lastIsCharging);
      }
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_device != null && _writeChar != null) {
      try {
        await _writeChar!.write(_ankerAuthPayload, withoutResponse: true);
      } catch (e) {
        _device = null;
      }
    } else if (!_isConnecting && _targetDeviceId != null) {
      _connectDirectly(_targetDeviceId!);
    }
  }

  void _checkAlarm(int soc, bool isChargingFromAC) async {
    if (soc >= _fullThreshold && isChargingFromAC) {
      if (_isLowAlarmActive) _stopAlarm();

      if (!_isFullAlarmActive && !_isSnoozed()) {
        _isFullAlarmActive = true;
        _startAlarmRinging('Anker: $soc% (🔋 Заряджено!)',
            'Досягнуто $_fullThreshold%. Вимкніть генератор!');
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('audio/full_charge.ogg'));
      }
      return;
    } else {
      if (_isFullAlarmActive) {
        _stopAlarm();
        _snoozeUntil = null;
      }
    }

    if (isChargingFromAC) {
      if (_isLowAlarmActive) {
        _stopAlarm();
        _snoozeUntil = null;
      }
      return;
    }

    if (soc <= _currentThreshold) {
      if (!_isLowAlarmActive && !_isSnoozed()) {
        _stopAlarm();
        _isLowAlarmActive = true;
        _startAlarmRinging('Anker: $soc% (⚠️ Низький заряд)',
            'Низький заряд батареї (<= $_currentThreshold%)!');
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('audio/alarm_clock.ogg'));
      }
    } else {
      if (_isLowAlarmActive) {
        _stopAlarm();
        _snoozeUntil = null;
      }
    }
  }

  void _startAlarmRinging(String title, String text) {
    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationButtons: [
        const NotificationButton(id: 'btn_snooze', text: 'Заглушити сигнал'),
      ],
    );
  }

  void _stopAlarm() async {
    if (_isLowAlarmActive || _isFullAlarmActive) {
      _isLowAlarmActive = false;
      _isFullAlarmActive = false;
      await _audioPlayer.stop();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _telemetrySub?.cancel();
    _connStateSub?.cancel();
    await _device?.disconnect();
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
  }
}
