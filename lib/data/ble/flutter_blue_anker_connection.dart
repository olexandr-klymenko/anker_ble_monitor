import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/telemetry_parser.dart';
import 'anker_connection.dart';

/// [AnkerConnection] поверх пакету `flutter_blue_plus`.
///
/// Уся логіка тут перенесена без змін поведінки з попередньої версії
/// [AnkerBackgroundTaskHandler] — той самий порядок discover -> match
/// characteristic -> subscribe/keep-alive. Виправлено лише один
/// попередній недогляд: цикл по характеристиках раніше викликав
/// `_subscribeTelemetry` без `await`, тож якщо characteristic зі
/// збігом `8888` трапилась двічі (інша прошивка/дублікат сервісу),
/// можна було підписатись на телеметрію двічі підряд.
class FlutterBlueAnkerConnection implements AnkerConnection {
  /// Фрагмент UUID характеристики запису (куди періодично надсилається
  /// [_ankerAuthPayload]). Повний UUID може відрізнятись між прошивками
  /// станції, тому звіряємось лише за характерним фрагментом — визначено
  /// емпірично (реверс-інжиніринг), офіційної специфікації немає.
  static const String _writeCharacteristicUuidFragment = '7777';

  /// Фрагмент UUID характеристики телеметрії (notify зі станом заряду,
  /// див. [TelemetryParser]). Так само визначено емпірично.
  static const String _telemetryCharacteristicUuidFragment = '8888';

  /// Фіксований байт-пакет, який офіційний застосунок Anker надсилає в
  /// характеристику запису, щоб підтримувати BLE-сесію автентифікованою
  /// (keep-alive). Отримано реверс-інжинірингом трафіку офіційного
  /// застосунку — призначення окремих байтів невідоме, тому пакет
  /// надсилається як є, без розбору.
  static const List<int> _ankerAuthPayload = [
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

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  bool _isConnecting = false;

  final StreamController<TelemetryParseResult> _telemetryController =
      StreamController<TelemetryParseResult>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  @override
  Stream<TelemetryParseResult> get telemetry => _telemetryController.stream;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  bool get isConnected => _device != null;

  @override
  Future<void> connect(String deviceId) async {
    if (_device != null || _isConnecting) return;
    _isConnecting = true;

    try {
      final BluetoothDevice dev = BluetoothDevice.fromId(deviceId);
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
          _connectionController.add(false);
        }
      });

      final List<BluetoothService> services = await dev.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          final String uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains(_writeCharacteristicUuidFragment)) _writeChar = c;
          if (uuid.contains(_telemetryCharacteristicUuidFragment)) {
            await _subscribeTelemetry(c);
          }
        }
      }
    } catch (e) {
      debugPrint('AnkerConnection: connect($deviceId) failed: $e');
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
      if (parseResult != null) _telemetryController.add(parseResult);
    });
  }

  @override
  Future<void> disconnect() async {
    await _telemetrySub?.cancel();
    await _connStateSub?.cancel();
    _telemetrySub = null;
    _connStateSub = null;
    await _device?.disconnect();
    _device = null;
    _writeChar = null;
  }

  @override
  Future<void> sendKeepAlive() async {
    final device = _device;
    final writeChar = _writeChar;
    if (device == null || writeChar == null) return;

    try {
      await writeChar.write(_ankerAuthPayload, withoutResponse: true);
    } catch (e) {
      // Так само, як і раніше: невдалий запис лише скидає локальний стан
      // з'єднання (наступний тік спробує перепідключитись) — без окремої
      // нотифікації, бо реальний розрив BLE-стек однаково повідомить через
      // connectionState.
      debugPrint('AnkerConnection: keep-alive write failed: $e');
      _device = null;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _telemetryController.close();
    await _connectionController.close();
  }
}
