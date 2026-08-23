import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/ipc/telemetry_channel.dart';
import 'package:anker_ble_monitor/models/anker_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('publish() доставляє телеметрію підписнику через stream', () async {
    final channel = TelemetryChannel.subscribe();
    addTearDown(channel.close);

    final future = channel.stream.first;
    TelemetryChannel.publish(AnkerTelemetry(
      isAlarmRinging: true,
      soc: 42,
      isCharging: true,
    ));

    final received = await future;

    expect(received.soc, 42);
    expect(received.isAlarmRinging, isTrue);
    expect(received.isCharging, isTrue);
  });

  test('close() знімає mapping порту — publish() після цього нічого не '
      'доставляє й не падає', () async {
    final channel = TelemetryChannel.subscribe();
    channel.close();

    expect(
      () => TelemetryChannel.publish(AnkerTelemetry(
        isAlarmRinging: false,
        soc: 10,
          isCharging: false,
      )),
      returnsNormally,
    );
  });

  test('повторна subscribe() перереєструє порт під тією ж назвою без падіння',
      () async {
    final first = TelemetryChannel.subscribe();
    final second = TelemetryChannel.subscribe();
    addTearDown(second.close);

    final future = second.stream.first;
    TelemetryChannel.publish(AnkerTelemetry(
      isAlarmRinging: false,
      soc: 7,
      isCharging: false,
    ));

    final received = await future;
    expect(received.soc, 7);

    first.close();
  });
}
