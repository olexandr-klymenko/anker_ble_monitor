import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/domain/alarm_controller.dart';
import 'package:anker_ble_monitor/domain/models/monitor_settings.dart';
import 'package:anker_ble_monitor/domain/monitor_notification_builder.dart';

const _settings = MonitorSettings(
  lowThreshold: 15,
  fullThreshold: 100,
  snoozeMinutes: 3,
);

AlarmEvaluation _evaluation({
  AlarmAudioAction audioAction = AlarmAudioAction.none,
  bool isLowAlarmActive = false,
  bool isFullAlarmActive = false,
  bool isSnoozed = false,
  bool lowConditionMet = false,
  bool fullConditionMet = false,
  int remainingSnoozeMinutes = 0,
}) =>
    AlarmEvaluation(
      audioAction: audioAction,
      isLowAlarmActive: isLowAlarmActive,
      isFullAlarmActive: isFullAlarmActive,
      isSnoozed: isSnoozed,
      lowConditionMet: lowConditionMet,
      fullConditionMet: fullConditionMet,
      remainingSnoozeMinutes: remainingSnoozeMinutes,
    );

void main() {
  group('MonitorNotificationBuilder — знімки побудовані вручну', () {
    test('Тривога низького заряду активна -> текст + кнопка "Заглушити"', () {
      final content = MonitorNotificationBuilder.build(
        evaluation: _evaluation(isLowAlarmActive: true, lowConditionMet: true),
        settings: _settings,
        soc: 10,
        isCharging: false,
      );

      expect(content.title, 'Anker: 10% (⚠️ Низький заряд)');
      expect(content.text, 'Низький заряд батареї (<= 15%)!');
      expect(content.showSnoozeButton, isTrue);
    });

    test('Тривога повного заряду активна -> текст + кнопка "Заглушити"', () {
      final content = MonitorNotificationBuilder.build(
        evaluation:
            _evaluation(isFullAlarmActive: true, fullConditionMet: true),
        settings: _settings,
        soc: 100,
        isCharging: true,
      );

      expect(content.title, 'Anker: 100% (🔋 Заряджено!)');
      expect(content.text, 'Досягнуто 100%. Вимкніть генератор!');
      expect(content.showSnoozeButton, isTrue);
    });

    test('Умова низького заряду виконана, але заглушена паузою -> текст паузи '
        'без кнопки', () {
      final content = MonitorNotificationBuilder.build(
        evaluation: _evaluation(
          lowConditionMet: true,
          isSnoozed: true,
          remainingSnoozeMinutes: 2,
        ),
        settings: _settings,
        soc: 10,
        isCharging: false,
      );

      expect(content.title, 'Anker: 10% (🔕 Пауза)');
      expect(content.text,
          '⚠️ Низький заряд (<= 15%). Звук заглушено на 2 хв');
      expect(content.showSnoozeButton, isFalse);
    });

    test('Умова повного заряду виконана, але заглушена паузою -> текст паузи '
        'з правильним іконками зарядки', () {
      final content = MonitorNotificationBuilder.build(
        evaluation: _evaluation(
          fullConditionMet: true,
          isSnoozed: true,
          remainingSnoozeMinutes: 1,
        ),
        settings: _settings,
        soc: 100,
        isCharging: true,
      );

      expect(content.title, 'Anker: 100% (🔕 Пауза)');
      expect(content.text, '⚡ Досягнуто 100%. Звук заглушено на 1 хв');
      expect(content.showSnoozeButton, isFalse);
    });

    test('Умова виконана, але паузи немає (щойно скасована) -> звичайний '
        'заряджається/не заряджається текст, а не текст паузи', () {
      final content = MonitorNotificationBuilder.build(
        evaluation: _evaluation(lowConditionMet: true, isSnoozed: false),
        settings: _settings,
        soc: 10,
        isCharging: false,
      );

      expect(content.title, 'Anker: 10%');
      expect(content.text, 'Заряд під контролем (поріг: 15%)');
    });

    test('Немає тривоги, є зарядка -> "Заряджається"', () {
      final content = MonitorNotificationBuilder.build(
        evaluation: _evaluation(),
        settings: _settings,
        soc: 50,
        isCharging: true,
      );

      expect(content.title, 'Anker: 50% (⚡ Заряджається)');
      expect(content.text, 'Живлення підключено.');
      expect(content.showSnoozeButton, isFalse);
    });

    test('Немає тривоги, немає зарядки -> нейтральний статус', () {
      final content = MonitorNotificationBuilder.build(
        evaluation: _evaluation(),
        settings: _settings,
        soc: 50,
        isCharging: false,
      );

      expect(content.title, 'Anker: 50%');
      expect(content.text, 'Заряд під контролем (поріг: 15%)');
      expect(content.showSnoozeButton, isFalse);
    });
  });

  group('MonitorNotificationBuilder — інтеграція з реальним AlarmController',
      () {
    test(
        'Один AlarmEvaluation з AlarmController.evaluate() дає узгоджену '
        'нотифікацію паузи без повторного порівняння порогів у виклику', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final evaluation = controller.evaluate(
        soc: 10,
        isCharging: false,
        lowThreshold: 15,
        fullThreshold: 100,
        now: now.add(const Duration(minutes: 1, seconds: 10)),
      );

      final content = MonitorNotificationBuilder.build(
        evaluation: evaluation,
        settings: _settings,
        soc: 10,
        isCharging: false,
      );

      expect(content.title, 'Anker: 10% (🔕 Пауза)');
      // Лишилось 1хв50с до кінця 3-хвилинної паузи -> округлення вгору до 2.
      expect(content.text,
          '⚠️ Низький заряд (<= 15%). Звук заглушено на 2 хв');
    });

    test('Заряд відновився під час паузи -> AlarmController сам знімає паузу, '
        'нотифікація одразу переходить на нейтральний текст', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final evaluation = controller.evaluate(
        soc: 50,
        isCharging: false,
        lowThreshold: 15,
        fullThreshold: 100,
        now: now.add(const Duration(seconds: 30)),
      );

      final content = MonitorNotificationBuilder.build(
        evaluation: evaluation,
        settings: _settings,
        soc: 50,
        isCharging: false,
      );

      expect(content.title, 'Anker: 50%');
      expect(content.text, 'Заряд під контролем (поріг: 15%)');
    });
  });
}
