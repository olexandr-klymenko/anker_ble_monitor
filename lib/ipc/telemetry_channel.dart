import 'dart:isolate';
import 'dart:ui';
import '../models/anker_telemetry.dart';

/// Канал телеметрії фоновий ізолят -> UI, поверх [IsolateNameServer].
///
/// [subscribe] реєструє іменований порт і повертає канал, який власник
/// зобов'язаний закрити через [close] (наприклад, у `State.dispose()`).
/// Раніше підписка лише скасовувала `StreamSubscription`, а сам
/// [ReceivePort] і mapping у [IsolateNameServer] лишались зареєстрованими
/// назавжди — фон продовжував слати дані в порт, який ніхто вже не читає.
class TelemetryChannel {
  static const String _portName = 'anker_alarm_port';

  final ReceivePort _receivePort;
  late final Stream<AnkerTelemetry> stream;

  TelemetryChannel._(this._receivePort) {
    stream = _receivePort.map(_decode);
  }

  /// UI підписується на потік телеметрії. Знімає попередній mapping з тією
  /// самою назвою порту, щоб hot-restart чи повторний виклик не лишали
  /// підвислий порт від попередньої підписки.
  factory TelemetryChannel.subscribe() {
    IsolateNameServer.removePortNameMapping(_portName);
    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _portName);
    return TelemetryChannel._(receivePort);
  }

  /// Фоновий сервіс публікує телеметрію. Якщо підписника зараз немає
  /// (порт не зареєстровано), повідомлення просто губиться.
  static void publish(AnkerTelemetry telemetry) {
    final sendPort = IsolateNameServer.lookupPortByName(_portName);
    sendPort?.send(telemetry.toJson());
  }

  static AnkerTelemetry _decode(dynamic data) {
    if (data is Map) {
      return AnkerTelemetry.fromJson(Map<String, dynamic>.from(data));
    }
    return AnkerTelemetry(
      isAlarmRinging: false,
      soc: -1,
      isCharging: false,
    );
  }

  /// Знімає mapping порту і закриває [ReceivePort]. Після цього
  /// [publish] більше не досягає цього каналу.
  void close() {
    IsolateNameServer.removePortNameMapping(_portName);
    _receivePort.close();
  }
}
