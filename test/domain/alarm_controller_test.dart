import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/domain/alarm_controller.dart';

void main() {
  group('AlarmController — базові стани (без тривоги)', () {
    test('Немає тривоги, коли заряд між порогами і немає зарядки', () {
      final controller = AlarmController();

      final result = controller.evaluate(
        soc: 50,
        isCharging: false,
        lowThreshold: 15,
        fullThreshold: 100,
      );

      expect(result.audioAction, AlarmAudioAction.none);
      expect(result.isLowAlarmActive, isFalse);
      expect(result.isFullAlarmActive, isFalse);
      expect(result.isAlarmRinging, isFalse);
    });
  });

  group('AlarmController — тривога низького заряду', () {
    test('Спрацьовує, коли soc <= lowThreshold і немає зарядки', () {
      final controller = AlarmController();

      final result = controller.evaluate(
        soc: 15,
        isCharging: false,
        lowThreshold: 15,
        fullThreshold: 100,
      );

      expect(result.audioAction, AlarmAudioAction.playLow);
      expect(result.isLowAlarmActive, isTrue);
      expect(result.isAlarmRinging, isTrue);
    });

    test('Не перезапускається повторно, поки вже активна (ідемпотентність)',
        () {
      final controller = AlarmController();

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100);
      final second = controller.evaluate(
          soc: 8, isCharging: false, lowThreshold: 15, fullThreshold: 100);

      expect(second.audioAction, AlarmAudioAction.none);
      expect(second.isLowAlarmActive, isTrue);
    });

    test('Гаситься, коли заряд піднявся вище порогу', () {
      final controller = AlarmController();

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100);
      final result = controller.evaluate(
          soc: 20, isCharging: false, lowThreshold: 15, fullThreshold: 100);

      expect(result.audioAction, AlarmAudioAction.stop);
      expect(result.isLowAlarmActive, isFalse);
      expect(result.isAlarmRinging, isFalse);
    });

    test('Гаситься миттєво, щойно з\'явилась мережа (AC-in скасовує тривогу)',
        () {
      final controller = AlarmController();

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100);
      final result = controller.evaluate(
          soc: 10, isCharging: true, lowThreshold: 15, fullThreshold: 100);

      expect(result.audioAction, AlarmAudioAction.stop);
      expect(result.isLowAlarmActive, isFalse);
    });
  });

  group('AlarmController — тривога повного заряду', () {
    test('Спрацьовує, коли soc >= fullThreshold і йде зарядка', () {
      final controller = AlarmController();

      final result = controller.evaluate(
          soc: 100, isCharging: true, lowThreshold: 15, fullThreshold: 100);

      expect(result.audioAction, AlarmAudioAction.playFull);
      expect(result.isFullAlarmActive, isTrue);
      expect(result.isAlarmRinging, isTrue);
    });

    test('Гаситься, коли живлення від мережі зникло', () {
      final controller = AlarmController();

      controller.evaluate(
          soc: 100, isCharging: true, lowThreshold: 15, fullThreshold: 100);
      final result = controller.evaluate(
          soc: 100, isCharging: false, lowThreshold: 15, fullThreshold: 100);

      expect(result.audioAction, AlarmAudioAction.stop);
      expect(result.isFullAlarmActive, isFalse);
    });

    test(
        'Перехід low -> full: активна тривога розряду гаситься, '
        'запускається тривога повного заряду одним кроком', () {
      final controller = AlarmController();

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100);
      final result = controller.evaluate(
          soc: 100, isCharging: true, lowThreshold: 15, fullThreshold: 100);

      // Контролер повертає фінальну дію (playFull), але внутрішній стан
      // коректно відображає, що low вимкнено, а full увімкнено.
      expect(result.audioAction, AlarmAudioAction.playFull);
      expect(result.isLowAlarmActive, isFalse);
      expect(result.isFullAlarmActive, isTrue);
    });
  });

  group('AlarmController — межові значення порогів', () {
    test('soc == lowThreshold теж тригерить тривогу (<=)', () {
      final controller = AlarmController();
      final result = controller.evaluate(
          soc: 15, isCharging: false, lowThreshold: 15, fullThreshold: 100);
      expect(result.isLowAlarmActive, isTrue);
    });

    test('soc == fullThreshold теж тригерить тривогу (>=)', () {
      final controller = AlarmController();
      final result = controller.evaluate(
          soc: 90, isCharging: true, lowThreshold: 15, fullThreshold: 90);
      expect(result.isFullAlarmActive, isTrue);
    });

    test('soc на 1% вище lowThreshold тривогу НЕ запускає', () {
      final controller = AlarmController();
      final result = controller.evaluate(
          soc: 16, isCharging: false, lowThreshold: 15, fullThreshold: 100);
      expect(result.isLowAlarmActive, isFalse);
    });
  });

  group('AlarmController — snooze (ручна пауза)', () {
    test('Заглушує активну тривогу і повертає stop', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now);
      final snoozeResult =
          controller.activateSnooze(const Duration(minutes: 3), now: now);

      expect(snoozeResult.audioAction, AlarmAudioAction.stop);
      expect(snoozeResult.isLowAlarmActive, isFalse);
      expect(snoozeResult.isSnoozed, isTrue);
    });

    test('Нічого не грає, якщо нічого не дзвонило (лише встановлює паузу)', () {
      final controller = AlarmController();
      final result = controller.activateSnooze(const Duration(minutes: 3));

      expect(result.audioAction, AlarmAudioAction.none);
      expect(result.isSnoozed, isTrue);
    });

    test('Поки триває пауза, умова тривоги повторно НЕ запускає сигнал', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final duringSnooze = controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(minutes: 1)));

      expect(duringSnooze.audioAction, AlarmAudioAction.none);
      expect(duringSnooze.isAlarmRinging, isFalse);
    });

    test('Тривога відновлюється одразу після завершення паузи', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final afterSnooze = controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(minutes: 3, seconds: 1)));

      expect(afterSnooze.audioAction, AlarmAudioAction.playLow);
      expect(afterSnooze.isAlarmRinging, isTrue);
    });

    test('Заряд відновився під час паузи -> пауза скасовується достроково', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      // Заряд піднявся вище порогу під час паузи.
      final result = controller.evaluate(
          soc: 20,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(seconds: 30)));

      expect(result.isSnoozed, isFalse,
          reason: 'Умова, що спричинила тривогу, зникла -> пауза більше '
              'не потрібна');
      expect(result.audioAction, AlarmAudioAction.none,
          reason: 'Нічого не звучало (було заглушено), тож і зупиняти '
              'нічого');
    });

    test(
        'Після дострокового скасування паузи наступне повернення умови '
        'знову тригерить тривогу', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);
      controller.evaluate(
          soc: 20,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(seconds: 30)));

      final result = controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(seconds: 40)));

      expect(result.audioAction, AlarmAudioAction.playLow);
      expect(result.isAlarmRinging, isTrue);
    });

    test('remainingSnoozeMinutes рахує залишок з округленням вгору', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final remaining = controller.remainingSnoozeMinutes(
          now.add(const Duration(minutes: 1, seconds: 10)));

      // Лишилось 1хв50с -> округлення вгору до 2.
      expect(remaining, 2);
    });

    test('remainingSnoozeMinutes повертає 0, якщо паузи немає', () {
      final controller = AlarmController();
      expect(controller.remainingSnoozeMinutes(DateTime.now()), 0);
    });
  });

  group('AlarmController — lowConditionMet/fullConditionMet/remainingSnoozeMinutes',
      () {
    test('evaluate() повертає lowConditionMet=true навіть коли тривога '
        'заглушена паузою', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final result = controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100,
          now: now.add(const Duration(seconds: 30)));

      expect(result.lowConditionMet, isTrue);
      expect(result.fullConditionMet, isFalse);
      expect(result.isLowAlarmActive, isFalse,
          reason: 'заглушено паузою, тому не активна фізично');
      expect(result.conditionMet, isTrue);
    });

    test('evaluate() повертає обидва conditionMet=false, коли жодна умова не '
        'виконана', () {
      final controller = AlarmController();
      final result = controller.evaluate(
          soc: 50, isCharging: false, lowThreshold: 15, fullThreshold: 100);

      expect(result.lowConditionMet, isFalse);
      expect(result.fullConditionMet, isFalse);
      expect(result.conditionMet, isFalse);
    });

    test('evaluate() рахує remainingSnoozeMinutes для переданого now', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100,
          now: now);
      controller.activateSnooze(const Duration(minutes: 3), now: now);

      final result = controller.evaluate(
          soc: 10, isCharging: false, lowThreshold: 15, fullThreshold: 100,
          now: now.add(const Duration(minutes: 1, seconds: 10)));

      // Лишилось 1хв50с -> округлення вгору до 2, як і в remainingSnoozeMinutes().
      expect(result.remainingSnoozeMinutes, 2);
    });

    test('evaluate() без паузи -> remainingSnoozeMinutes дорівнює 0', () {
      final controller = AlarmController();
      final result = controller.evaluate(
          soc: 50, isCharging: false, lowThreshold: 15, fullThreshold: 100);

      expect(result.remainingSnoozeMinutes, 0);
    });

    test(
        'activateSnooze() відображає, яка саме тривога щойно дзвонила, у '
        'lowConditionMet/fullConditionMet поверненого знімка', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      controller.evaluate(
          soc: 100, isCharging: true, lowThreshold: 15, fullThreshold: 100,
          now: now);
      final result =
          controller.activateSnooze(const Duration(minutes: 3), now: now);

      expect(result.fullConditionMet, isTrue);
      expect(result.lowConditionMet, isFalse);
    });

    test('activateSnooze() без активної тривоги -> обидва conditionMet=false',
        () {
      final controller = AlarmController();
      final result =
          controller.activateSnooze(const Duration(minutes: 3));

      expect(result.lowConditionMet, isFalse);
      expect(result.fullConditionMet, isFalse);
    });
  });

  group('AlarmController — скасування паузи спрацьовує навіть без дзвінка', () {
    test(
        'AC з\'являється під час паузи, поки тривога жодного разу не '
        'продзвонила -> пауза все одно коректно скасовується', () {
      final controller = AlarmController();
      final now = DateTime(2026, 1, 1, 12, 0);

      // Пауза активована заздалегідь (наприклад, користувач заглушив
      // попередню тривогу).
      controller.activateSnooze(const Duration(minutes: 5), now: now);

      // Низький заряд настає під час паузи — тривога не стартує (заглушена).
      final duringSnooze = controller.evaluate(
          soc: 10,
          isCharging: false,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(minutes: 1)));
      expect(duringSnooze.isLowAlarmActive, isFalse);
      expect(duringSnooze.isSnoozed, isTrue);

      // З'являється AC -> умова низького заряду зникла -> пауза
      // скасовується, попри те що тривога жодного разу не звучала.
      final acIn = controller.evaluate(
          soc: 10,
          isCharging: true,
          lowThreshold: 15,
          fullThreshold: 100,
          now: now.add(const Duration(minutes: 2)));
      expect(acIn.isSnoozed, isFalse);
      expect(acIn.audioAction, AlarmAudioAction.none);
    });
  });
}
