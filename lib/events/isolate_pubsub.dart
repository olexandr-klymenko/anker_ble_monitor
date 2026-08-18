import 'dart:isolate';
import 'dart:ui';

class AnkerTelemetry {
  final bool isAlarmRinging;
  final int soc; // Відсоток заряду (0-100)
  final int acInWatts; // Потужність заряджання Вт
  final bool isCharging;

  AnkerTelemetry({
    required this.isAlarmRinging,
    required this.soc,
    required this.acInWatts,
    required this.isCharging,
  });

  Map<String, dynamic> toJson() => {
        'isAlarmRinging': isAlarmRinging,
        'soc': soc,
        'acInWatts': acInWatts,
        'isCharging': isCharging,
      };

  factory AnkerTelemetry.fromJson(Map<String, dynamic> json) {
    return AnkerTelemetry(
      isAlarmRinging: json['isAlarmRinging'] as bool? ?? false,
      soc: json['soc'] as int? ?? -1,
      acInWatts: json['acInWatts'] as int? ?? 0,
      isCharging: json['isCharging'] as bool? ?? false,
    );
  }
}

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
