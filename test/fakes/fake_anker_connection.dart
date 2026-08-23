import 'dart:async';
import 'package:anker_ble_monitor/data/ble/anker_connection.dart';
import 'package:anker_ble_monitor/services/telemetry_parser.dart';

/// Тестовий двійник [AnkerConnection] — без жодного BLE-стека. Тест керує
/// станом підключення й телеметрією напряму через [emitTelemetry]/
/// [connect]/[dropConnection], а [connectCalls]/[keepAliveCalls] дають
/// перевірити, що [MonitorService] реагує на події правильними викликами.
class FakeAnkerConnection implements AnkerConnection {
  // sync: true — тести не мають чекати мікротаск, щоб перевірити ефект
  // одразу після emitTelemetry()/dropConnection().
  final StreamController<TelemetryParseResult> _telemetryController =
      StreamController<TelemetryParseResult>.broadcast(sync: true);
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast(sync: true);

  final List<String> connectCalls = [];
  int keepAliveCalls = 0;
  int disconnectCalls = 0;
  bool disposed = false;

  bool _isConnected = false;

  /// Якщо `true`, наступний [connect] одразу переводить з'єднання в
  /// підключений стан (типовий сценарій "станція доступна").
  bool autoConnectSucceeds = true;

  @override
  Stream<TelemetryParseResult> get telemetry => _telemetryController.stream;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    if (autoConnectSucceeds) {
      _isConnected = true;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _isConnected = false;
  }

  @override
  Future<void> sendKeepAlive() async {
    keepAliveCalls++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _telemetryController.close();
    await _connectionController.close();
  }

  /// Симулює отримання пакета телеметрії від станції.
  void emitTelemetry({required int soc, required bool isCharging}) {
    _telemetryController.add(TelemetryParseResult(soc: soc, isCharging: isCharging));
  }

  /// Симулює реальний розрив BLE-з'єднання (не невдалу спробу connect()).
  void dropConnection() {
    _isConnected = false;
    _connectionController.add(false);
  }
}
