import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/domain/models/monitor_settings.dart';

void main() {
  group('MonitorSettings', () {
    test('defaults містять очікувані значення за замовчуванням', () {
      expect(MonitorSettings.defaults.lowThreshold, 15);
      expect(MonitorSettings.defaults.fullThreshold, 100);
      expect(MonitorSettings.defaults.snoozeMinutes, 3);
    });

    test('toJson/fromJson — round-trip зберігає значення', () {
      const settings = MonitorSettings(
        lowThreshold: 20,
        fullThreshold: 90,
        snoozeMinutes: 5,
      );

      final restored = MonitorSettings.fromJson(settings.toJson());

      expect(restored, equals(settings));
    });

    test('fromJson підставляє defaults для відсутніх ключів', () {
      final restored = MonitorSettings.fromJson({'lowThreshold': 25});

      expect(restored.lowThreshold, 25);
      expect(restored.fullThreshold, MonitorSettings.defaults.fullThreshold);
      expect(restored.snoozeMinutes, MonitorSettings.defaults.snoozeMinutes);
    });

    test('fromJson підставляє defaults для хибно типізованих значень', () {
      final restored = MonitorSettings.fromJson({
        'lowThreshold': 'not-an-int',
        'fullThreshold': 90,
        'snoozeMinutes': null,
      });

      expect(restored.lowThreshold, MonitorSettings.defaults.lowThreshold);
      expect(restored.fullThreshold, 90);
      expect(restored.snoozeMinutes, MonitorSettings.defaults.snoozeMinutes);
    });

    test('дві однаково заповнені інстанції рівні за значенням (value equality)',
        () {
      const a = MonitorSettings(lowThreshold: 10, fullThreshold: 95, snoozeMinutes: 4);
      const b = MonitorSettings(lowThreshold: 10, fullThreshold: 95, snoozeMinutes: 4);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('інстанції з різними полями не рівні', () {
      const a = MonitorSettings(lowThreshold: 10, fullThreshold: 95, snoozeMinutes: 4);
      const b = MonitorSettings(lowThreshold: 11, fullThreshold: 95, snoozeMinutes: 4);

      expect(a, isNot(equals(b)));
    });
  });
}
