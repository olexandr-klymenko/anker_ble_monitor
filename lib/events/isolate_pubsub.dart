import 'dart:isolate';
import 'dart:ui';
import '../models/anker_telemetry.dart';

class IsolatePubSub {
  static const String _portName = 'anker_alarm_port';

  /// UI підписується на потік телеметрії
  static Stream<AnkerTelemetry> subscribe() {
    IsolateNameServer.removePortNameMapping(_portName);

    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _portName);

    return receivePort.map((data) {
      if (data is Map<String, dynamic>) {
        return AnkerTelemetry.fromJson(data);
      }
      return AnkerTelemetry(
          isAlarmRinging: data == true,
          soc: -1,
          acInWatts: 0,
          isCharging: false);
    });
  }

  /// Фоновий сервіс публікує телеметрію
  static void publish(AnkerTelemetry telemetry) {
    final sendPort = IsolateNameServer.lookupPortByName(_portName);
    sendPort?.send(telemetry.toJson());
  }
}
