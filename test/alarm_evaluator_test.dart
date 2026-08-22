import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/services/alarm_evaluator.dart'; // Перевірте шлях імпорту

void main() {
  group('AlarmEvaluator Unit Tests', () {
    late AlarmEvaluator evaluator;

    setUp(() {
      evaluator = AlarmEvaluator(lowThreshold: 15, fullThreshold: 100);
    });

    test('Низький заряд: вмикає аларм при soc <= 15%', () {
      final action = evaluator.evaluate(
        soc: 10,
        isChargingFromAC: false,
        isSnoozed: false,
      );

      expect(action, AlarmAction.startLow);
      expect(evaluator.isLowAlarmActive, true);
    });

    test('Низький заряд: вимикає аларм при підключенні зарядки', () {
      evaluator.evaluate(soc: 10, isChargingFromAC: false, isSnoozed: false);
      expect(evaluator.isLowAlarmActive, true);

      final action = evaluator.evaluate(
        soc: 10,
        isChargingFromAC: true,
        isSnoozed: false,
      );

      expect(action, AlarmAction.stop);
      expect(evaluator.isLowAlarmActive, false);
    });

    test('Повний заряд: вимикає аларм, якщо генератор вимкнули ДО 100%', () {
      evaluator.isFullAlarmActive = true;

      final action = evaluator.evaluate(
        soc: 90,
        isChargingFromAC: false,
        isSnoozed: false,
      );

      expect(action, AlarmAction.stop);
      expect(evaluator.isFullAlarmActive, false);
    });

    test('Едж-кейс 100%: Аларм ПРОДОВЖУЄ грати, коли струм зупинився на 100%',
        () {
      // 1. Досягли 100% під час зарядки
      var action = evaluator.evaluate(
        soc: 100,
        isChargingFromAC: true,
        isSnoozed: false,
      );
      expect(action, AlarmAction.startFull);
      expect(evaluator.isFullAlarmActive, isTrue);

      // 2. BMS відсікає струм (isChargingFromAC = false), SOC залишається 100%
      action = evaluator.evaluate(
        soc: 100,
        isChargingFromAC: false,
        isSnoozed: false,
      );

      // ПЕРЕВІРКА:
      // На новій логіці action буде AlarmAction.none, а isFullAlarmActive — true.
      // На старій логіці action поверне AlarmAction.stop, а isFullAlarmActive стане false -> ТЕСТ ВПАДЕ!
      expect(action, AlarmAction.none);
      expect(evaluator.isFullAlarmActive, isTrue);
    });
  });
}
