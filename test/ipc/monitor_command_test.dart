import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/domain/models/monitor_settings.dart';
import 'package:anker_ble_monitor/ipc/monitor_command.dart';

void main() {
  group('MonitorCommand.fromJson', () {
    test('розпізнає SyncStateCommand і коректно відновлює вкладені settings',
        () {
      const original = SyncStateCommand(
        deviceId: 'AA:BB:CC:11:22:33',
        settings: MonitorSettings(
          lowThreshold: 20,
          fullThreshold: 90,
          snoozeMinutes: 5,
        ),
      );

      final decoded = MonitorCommand.fromJson(original.toJson());

      expect(decoded, equals(original));
    });

    test('розпізнає SnoozeCommand', () {
      final decoded = MonitorCommand.fromJson(const SnoozeCommand().toJson());

      expect(decoded, equals(const SnoozeCommand()));
    });

    test('повертає null для невідомого типу команди', () {
      final decoded = MonitorCommand.fromJson({'type': 'unknownCommand'});

      expect(decoded, isNull);
    });

    test('повертає null, якщо data взагалі не Map (легасі формат)', () {
      expect(MonitorCommand.fromJson('snooze'), isNull);
      expect(MonitorCommand.fromJson(true), isNull);
      expect(MonitorCommand.fromJson(null), isNull);
    });

    test('повертає null для syncState без обов\'язкових полів', () {
      expect(
        MonitorCommand.fromJson({'type': 'syncState'}),
        isNull,
      );
      expect(
        MonitorCommand.fromJson({
          'type': 'syncState',
          'deviceId': 'AA:BB:CC:11:22:33',
          // 'settings' відсутній
        }),
        isNull,
      );
    });

    test(
        'SyncStateCommand з однаковими значеннями рівні за value equality '
        '(а не лише за deviceId, як могло бути з мапою)', () {
      const a = SyncStateCommand(
        deviceId: 'AA:BB:CC:11:22:33',
        settings: MonitorSettings(
            lowThreshold: 15, fullThreshold: 100, snoozeMinutes: 3),
      );
      const b = SyncStateCommand(
        deviceId: 'AA:BB:CC:11:22:33',
        settings: MonitorSettings(
            lowThreshold: 15, fullThreshold: 100, snoozeMinutes: 3),
      );

      expect(a, equals(b));
    });
  });
}
