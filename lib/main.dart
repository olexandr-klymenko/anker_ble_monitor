import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/permission_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(AnkerBackgroundTaskHandler());
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnkerMonitorApp());
}

class AnkerMonitorApp extends StatelessWidget {
  const AnkerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anker 767 BLE Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _alarmThreshold = 15;
  bool _isServiceRunning = false;

  final List<int> _thresholdOptions = [
    5,
    10,
    15,
    20,
    25,
    30,
    40,
    50,
    60,
    70,
    80,
    85,
    90,
    95
  ];

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _checkServiceStatus();
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
        channelDescription: 'Стеження за станом заряду Anker 767 у фоні',
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
    bool permissionsGranted = await PermissionService.requestAllPermissions();
    if (!permissionsGranted) return;

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 257,
        notificationTitle: 'Anker 767 Monitor',
        notificationText: 'Підключення до станції...',
        callback: startCallback,
      );
    }

    setState(() {
      _isServiceRunning = true;
    });

    FlutterForegroundTask.sendDataToTask({'threshold': _alarmThreshold});
  }

  Future<void> _stopService() async {
    await FlutterForegroundTask.stopService();
    setState(() {
      _isServiceRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anker 767 BLE Monitor'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Наочна картка статусу фонової служби
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
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      Icon(
                        _isServiceRunning
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 72,
                        color: _isServiceRunning
                            ? Colors.greenAccent
                            : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isServiceRunning
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _isServiceRunning ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          _isServiceRunning
                              ? 'МОНІТОРИНГ АКТИВНИЙ'
                              : 'СЕРВІС ЗУПИНЕНО',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isServiceRunning
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isServiceRunning
                            ? 'Стеження працює у фоні. Поточний заряд дивіться у шторці сповіщень.'
                            : 'Натисніть кнопку нижче для запуску фонової служби.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Поріг тривоги:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<int>(
                      value: _alarmThreshold,
                      underline: const SizedBox(),
                      items: _thresholdOptions.map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            '$value%',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _alarmThreshold = newValue;
                          });
                          FlutterForegroundTask.sendDataToTask(
                            {'threshold': newValue},
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _startService,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Запустити фоновий сервіс',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _stopService,
                icon: const Icon(Icons.stop_rounded, size: 26),
                label: const Text(
                  'Зупинити фоновий сервіс',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnkerBackgroundTaskHandler extends TaskHandler {
  int _currentThreshold = 15;
  static String targetDeviceId = 'F4:9D:8A:25:D7:8B';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmActive = false;
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
    _connectDirectly(targetDeviceId);
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final threshold = data['threshold'];
      if (threshold != null && threshold is int) {
        _currentThreshold = threshold;
      }
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
            notificationTitle: 'Anker 767 Monitor',
            notificationText: 'Зв\'язок втрачено. Очікування...',
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
      if (bytes.length >= 122) {
        int soc = bytes[70];
        if (soc >= 0 && soc <= 100) {
          FlutterForegroundTask.updateService(
            notificationTitle: 'Anker 767: $soc%',
            notificationText:
                'Заряд під контролем (поріг: $_currentThreshold%)',
          );

          _checkAlarm(soc);
        }
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
    } else if (!_isConnecting) {
      _connectDirectly(targetDeviceId);
    }
  }

  void _checkAlarm(int soc) async {
    if (soc <= _currentThreshold && !_isAlarmActive) {
      _isAlarmActive = true;
      // Відтворення локального аудіофайлу з assets/audio/alarm.mp3
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/alarm_clock.ogg'));
    } else if (soc > _currentThreshold && _isAlarmActive) {
      _isAlarmActive = false;
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
