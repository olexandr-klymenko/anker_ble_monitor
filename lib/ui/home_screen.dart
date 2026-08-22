import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../events/isolate_pubsub.dart';
import '../models/anker_telemetry.dart';
import '../services/device_storage_service.dart';
import '../services/permission_service.dart';
import '../main.dart' show startCallback;
import 'device_scanner_dialog.dart';
import 'settings_screen.dart';
import 'widgets/action_buttons.dart';
import 'widgets/device_card.dart';
import 'widgets/telemetry_card.dart';

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
    _loadStoredSettings();
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

  Future<void> _loadStoredSettings() async {
    final settings = await DeviceStorageService.getSettings();
    setState(() {
      _alarmThreshold = settings['lowThreshold']!;
      _fullThreshold = settings['fullThreshold']!;
      _snoozeMinutes = settings['snoozeMinutes']!;
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDeviceManager());
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
      await DeviceStorageService.saveSettings(
        lowThreshold: _alarmThreshold,
        fullThreshold: _fullThreshold,
        snoozeMinutes: _snoozeMinutes,
      );
      _sendSettingsToTask();
    }
  }

  Future<void> _checkServiceStatus() async {
    bool running = await FlutterForegroundTask.isRunningService;
    setState(() => _isServiceRunning = running);
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

    if (!await PermissionService.requestAllPermissions()) return;

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

    setState(() => _isServiceRunning = true);
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
    setState(() => _isAlarmRinging = false);
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anker 767 BLE Monitor'),
          centerTitle: true,
          toolbarHeight: 48,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isTablet = constraints.maxWidth >= 600;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child:
                        isTablet ? _buildTabletLayout() : _buildMobileLayout(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeviceCard(
            device: _selectedDevice!,
            isServiceRunning: _isServiceRunning,
            onChange: _openDeviceManager,
          ),
          const SizedBox(height: 8),
          TelemetryCard(
            isServiceRunning: _isServiceRunning,
            telemetry: _latestTelemetry,
            lowThreshold: _alarmThreshold,
            fullThreshold: _fullThreshold,
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(),
          const SizedBox(height: 10),
          ActionButtons(
            isServiceRunning: _isServiceRunning,
            isAlarmRinging: _isAlarmRinging,
            snoozeMinutes: _snoozeMinutes,
            onSnooze: _snoozeAlarm,
            onStartService: _startService,
            onStopService: _stopService,
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeviceCard(
                device: _selectedDevice!,
                isServiceRunning: _isServiceRunning,
                onChange: _openDeviceManager,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TelemetryCard(
                  isServiceRunning: _isServiceRunning,
                  telemetry: _latestTelemetry,
                  lowThreshold: _alarmThreshold,
                  fullThreshold: _fullThreshold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSettingsCard(),
                const SizedBox(height: 8),
                ActionButtons(
                  isServiceRunning: _isServiceRunning,
                  isAlarmRinging: _isAlarmRinging,
                  snoozeMinutes: _snoozeMinutes,
                  onSnooze: _snoozeAlarm,
                  onStartService: _startService,
                  onStopService: _stopService,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Низький: $_alarmThreshold% | Повний: $_fullThreshold%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text('Пауза: $_snoozeMinutes хв',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.tune, color: Colors.blueAccent, size: 20),
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
    );
  }
}
