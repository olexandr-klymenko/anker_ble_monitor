import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/services/alarm_evaluator.dart'; // Перевірте шлях імпорту

// Інтеграційний фейк-хендлер для перевірки обробки подій
class TestableAnkerBackgroundTaskHandler {
  final AlarmEvaluator evaluator = AlarmEvaluator();

  bool get isFullAlarmActive => evaluator.isFullAlarmActive;
  bool get isLowAlarmActive => evaluator.isLowAlarmActive;

  void simulateTelemetry(int soc, bool isCharging) {
    final action = evaluator.evaluate(
      soc: soc,
      isChargingFromAC: isCharging,
      isSnoozed: false,
    );

    switch (action) {
      case AlarmAction.startFull:
        evaluator.isFullAlarmActive = true;
        break;
      case AlarmAction.startLow:
        evaluator.isLowAlarmActive = true;
        break;
      case AlarmAction.stop:
        evaluator.resetAll();
        break;
      case AlarmAction.none:
        break;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnkerBackgroundTaskHandler Integration Tests', () {
    late TestableAnkerBackgroundTaskHandler handler;

    setUp(() {
      handler = TestableAnkerBackgroundTaskHandler();
    });

    test('Низький заряд: активує alarm при soc <= 15%', () {
      handler.simulateTelemetry(10, false);
      expect(handler.isLowAlarmActive, isTrue);
    });

    test('Зняття низького заряду: вимикає alarm при підключенні живлення', () {
      handler.simulateTelemetry(10, false);
      expect(handler.isLowAlarmActive, isTrue);

      handler.simulateTelemetry(10, true);
      expect(handler.isLowAlarmActive, isFalse);
    });

    test('Повний заряд (Едж-кейс 100%): Сигнал триває, навіть якщо струм = 0',
        () {
      // 1. Прийшло 100% і струм є
      handler.simulateTelemetry(100, true);
      expect(handler.isFullAlarmActive, isTrue);

      // 2. BMS відсікає струм, приходить 100% і isCharging = false
      handler.simulateTelemetry(100, false);

      // Сигнал продовжує лунати
      expect(handler.isFullAlarmActive, isTrue);
    });

    test('Повний заряд: Вимикається, якщо живлення зникло ДО 100%', () {
      handler.evaluator.isFullAlarmActive = true;

      handler.simulateTelemetry(90, false);
      expect(handler.isFullAlarmActive, isFalse);
    });
  });
}
