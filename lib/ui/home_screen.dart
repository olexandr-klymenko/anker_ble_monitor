import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../events/isolate_pubsub.dart';
import '../services/device_storage_service.dart';
import '../services/permission_service.dart';
import '../main.dart' show startCallback;
import 'device_scanner_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _alarmThreshold = 15;
  int _fullThreshold = 100;
  int _snoozeMinutes = 3;
  bool _isServiceRunning = false;
  bool _isAlarmRinging = false;

  SavedDevice? _selectedDevice;
  AnkerTelemetry? _latestTelemetry;

  late StreamSubscription<AnkerTelemetry> _isolateSubscription;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _checkServiceStatus();
    _checkDeviceAndInit();

    _isolateSubscription = IsolatePubSub.subscribe().listen((telemetry) {
      setState(() {
        _latestTelemetry = telemetry;
        _isAlarmRinging = telemetry.isAlarmRinging;
      });
    });
  }

  @override
  void dispose() {
    _isolateSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkDeviceAndInit() async {
    final selectedId = await DeviceStorageService.getSelectedDeviceId();
    final devices = await DeviceStorageService.getSavedDevices();

    if (selectedId == null || !devices.any((d) => d.id == selectedId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDeviceManager();
      });
    } else {
      setState(() {
        _selectedDevice = devices.firstWhere((d) => d.id == selectedId);
      });
    }
  }

  Future<void> _openDeviceManager() async {
    if (_isServiceRunning) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DeviceManagerScreen()),
    );
    _checkDeviceAndInit();
    _sendSettingsToTask();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<Map<String, int>>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          lowThreshold: _alarmThreshold,
          fullThreshold: _fullThreshold,
          snoozeMinutes: _snoozeMinutes,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _alarmThreshold = result['lowThreshold']!;
        _fullThreshold = result['fullThreshold']!;
        _snoozeMinutes = result['snoozeMinutes']!;
      });
      _sendSettingsToTask();
    }
  }

  Future<void> _checkServiceStatus() async {
    bool running = await FlutterForegroundTask.isRunningService;
    setState(() {
      _isServiceRunning = running;
    });
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

  Future<void> _startService() async {
    if (_selectedDevice == null) {
      _openDeviceManager();
      return;
    }

    bool permissionsGranted = await PermissionService.requestAllPermissions();
    if (!permissionsGranted) return;

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 257,
        notificationTitle: 'Anker Monitor',
        notificationText: 'Підключення до станції...',
        callback: startCallback,
      );
    }

    setState(() {
      _isServiceRunning = true;
    });

    _sendSettingsToTask();
  }

  void _sendSettingsToTask() {
    if (_selectedDevice != null) {
      FlutterForegroundTask.sendDataToTask({
        'deviceId': _selectedDevice!.id,
        'threshold': _alarmThreshold,
        'fullThreshold': _fullThreshold,
        'snoozeDuration': _snoozeMinutes,
      });
    }
  }

  Future<void> _snoozeAlarm() async {
    FlutterForegroundTask.sendDataToTask({'action': 'snooze'});
    setState(() {
      _isAlarmRinging = false;
    });
  }

  Future<void> _stopService() async {
    await FlutterForegroundTask.stopService();
    setState(() {
      _isServiceRunning = false;
      _isAlarmRinging = false;
      _latestTelemetry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDevice == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anker 767 BLE Monitor'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.settings_bluetooth,
                color: _isServiceRunning ? Colors.grey : Colors.white,
              ),
              onPressed: _isServiceRunning ? null : _openDeviceManager,
              tooltip: 'Керування пристроями',
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Поточний вибраний пристрій
                  Card(
                    elevation: 2,
                    child: ListTile(
                      leading:
                          const Icon(Icons.power, color: Colors.blueAccent),
                      title: Text(
                        _selectedDevice!.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'BLE: ${_selectedDevice!.originalName} (${_selectedDevice!.id})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: TextButton(
                        onPressed:
                            _isServiceRunning ? null : _openDeviceManager,
                        child: Text(
                          'Змінити',
                          style: TextStyle(
                            color: _isServiceRunning
                                ? Colors.grey
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Віджет Статусу та Телеметрії
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isServiceRunning
                            ? Colors.greenAccent
                            : Colors.grey.shade700,
                        width: 2,
                      ),
                      color: _isServiceRunning
                          ? Colors.greenAccent.withValues(alpha: 0.08)
                          : Colors.grey.shade900,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isServiceRunning
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_disabled,
                                size: 28,
                                color: _isServiceRunning
                                    ? Colors.greenAccent
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isServiceRunning
                                    ? 'МОНІТОРИНГ АКТИВНИЙ'
                                    : 'СЕРВІС ЗУПИНЕНО',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isServiceRunning
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isServiceRunning &&
                              _latestTelemetry != null &&
                              _latestTelemetry!.soc >= 0) ...[
                            Text(
                              '${_latestTelemetry!.soc}%',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _latestTelemetry!.soc / 100.0,
                                minHeight: 12,
                                backgroundColor: Colors.grey.shade800,
                                color: _latestTelemetry!.soc <= _alarmThreshold
                                    ? Colors.redAccent
                                    : (_latestTelemetry!.soc >= _fullThreshold
                                        ? Colors.greenAccent
                                        : Colors.blueAccent),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_latestTelemetry!.isCharging)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bolt,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Заряджається: ${_latestTelemetry!.acInWatts} Вт',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Text(
                                'Живлення від мережі відсутнє',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                          ] else ...[
                            const Icon(Icons.battery_unknown,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              _isServiceRunning
                                  ? 'Очікування даних з Anker...'
                                  : 'Запустіть сервіс для отримання даних',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Інформаційний блок з поточними значеннями налаштувань
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Низький: $_alarmThreshold% | Повний: $_fullThreshold%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Пауза: $_snoozeMinutes хв',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune,
                                color: Colors.blueAccent),
                            onPressed: _openSettings,
                            tooltip: 'Налаштувати пороги',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (_isServiceRunning && _isAlarmRinging)
                        ? _snoozeAlarm
                        : null,
                    icon: const Icon(Icons.notifications_paused_rounded,
                        size: 22),
                    label: Text('Призупинити сигнал на $_snoozeMinutes хв',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: !_isServiceRunning ? _startService : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text('Запустити фоновий сервіс',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      disabledForegroundColor: Colors.grey.shade600,
                      side: BorderSide(
                        color: _isServiceRunning
                            ? Colors.redAccent
                            : Colors.grey.shade800,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isServiceRunning ? _stopService : null,
                    icon: const Icon(Icons.stop_rounded, size: 22),
                    label: const Text('Зупинити фоновий сервіс',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
