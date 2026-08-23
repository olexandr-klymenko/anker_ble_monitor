/// Дії, які викликач (наприклад, AnkerBackgroundTaskHandler) має виконати
/// з аудіо-програвачем у відповідь на [AlarmController.evaluate].
///
/// [playLow] і [playFull] завжди мають викликатись зі спочатку зупиненим
/// плеєром (caller сам робить stop() перед play(), щоб уникнути накладання
/// звуків) — сам контролер лише каже, ЩО грати, а не як.
enum AlarmAudioAction {
  /// Нічого не робити зі звуком.
  none,

  /// Зупинити поточний сигнал (без старту нового).
  stop,

  /// Зупинити поточний (якщо є) і почати грати сигнал низького заряду.
  playLow,

  /// Зупинити поточний (якщо є) і почати грати сигнал повного заряду.
  playFull,
}

/// Результат одного виклику [AlarmController.evaluate] або
/// [AlarmController.activateSnooze] — знімок стану + що робити зі звуком.
///
/// [lowConditionMet]/[fullConditionMet] і [remainingSnoozeMinutes] існують
/// спеціально для того, щоб викликачу (наприклад, побудові тексту
/// нотифікації) ніколи не доводилось самостійно повторно порівнювати
/// `soc` з порогами чи рахувати залишок паузи — це єдине джерело правди
/// для цих умов, обчислене тут же, всередині контролера.
class AlarmEvaluation {
  final AlarmAudioAction audioAction;
  final bool isLowAlarmActive;
  final bool isFullAlarmActive;
  final bool isSnoozed;

  /// Чи виконана прямо зараз умова тривоги низького заряду
  /// (`soc <= lowThreshold` і немає зарядки) — незалежно від того, чи
  /// заглушена вона паузою.
  final bool lowConditionMet;

  /// Чи виконана прямо зараз умова тривоги повного заряду
  /// (`soc >= fullThreshold` і йде зарядка) — незалежно від паузи.
  final bool fullConditionMet;

  /// Скільки хвилин лишилось до кінця паузи (округлення вгору), або 0,
  /// якщо паузи немає.
  final int remainingSnoozeMinutes;

  const AlarmEvaluation({
    required this.audioAction,
    required this.isLowAlarmActive,
    required this.isFullAlarmActive,
    required this.isSnoozed,
    required this.lowConditionMet,
    required this.fullConditionMet,
    required this.remainingSnoozeMinutes,
  });

  /// Чи виконана прямо зараз будь-яка з умов тривоги, незалежно від паузи.
  bool get conditionMet => lowConditionMet || fullConditionMet;

  /// Чи повинна зараз реально звучати/показуватись тривога.
  /// Використовується, наприклад, для поля `isAlarmRinging`
  /// у [AnkerTelemetry], яке публікується в UI-isolate.
  bool get isAlarmRinging =>
      (isLowAlarmActive || isFullAlarmActive) && !isSnoozed;

  @override
  String toString() =>
      'AlarmEvaluation(audioAction: $audioAction, low: $isLowAlarmActive, '
      'full: $isFullAlarmActive, snoozed: $isSnoozed, '
      'lowConditionMet: $lowConditionMet, fullConditionMet: $fullConditionMet, '
      'remainingSnoozeMinutes: $remainingSnoozeMinutes)';
}

/// Чиста стейт-машина сигналізації Anker-монітора.
///
/// Не залежить від Flutter, BLE чи AudioPlayer — тільки від переданих
/// значень (soc, isCharging, пороги, час), тому легко тестується юніт-тестами
/// без моків платформи. Побічні ефекти (гра звуку, оновлення нотифікації)
/// виконує викликач на основі поверненого [AlarmEvaluation.audioAction].
///
/// Правила:
/// 1. Якщо soc >= fullThreshold і йде зарядка від мережі — тривога "повний
///    заряд" (якщо не в snooze). Якщо перед цим була активна тривога
///    низького заряду — вона гаситься.
/// 2. Інакше, якщо йде зарядка від мережі — жодних тривог, будь-яка активна
///    тривога низького заряду гаситься.
/// 3. Інакше (немає зарядки), якщо soc <= lowThreshold — тривога "низький
///    заряд" (якщо не в snooze).
/// 4. Якщо жодна умова не виконана — активні тривоги гасяться.
///
/// **Скасування паузи (snooze):** якщо умова, що спричинила тривогу,
/// зникає (заряд відновився, з'явилась/зникла мережа тощо), активна пауза
/// скасовується одразу — незалежно від того, чи встигла тривога реально
/// продзвеніти в цей момент, чи була одразу заглушена паузою. Це
/// відстежується окремо від "чи зараз грає звук", інакше пауза могла б
/// пережити свою причину аж до власного таймауту навіть тоді, коли умова
/// вже давно неактуальна.
class AlarmController {
  bool _isLowAlarmActive = false;
  bool _isFullAlarmActive = false;
  DateTime? _snoozeUntil;

  /// Чи була умова тривоги (low або full, незалежно від snooze) активна
  /// на попередньому виклику [evaluate]. Потрібна окремо від
  /// [_isLowAlarmActive]/[_isFullAlarmActive], бо ті гасяться миттєво під
  /// час [activateSnooze] і більше не відображають, чи умова досі триває.
  bool _wasAlarmConditionMet = false;

  /// Чи активна пауза (snooze) прямо зараз. Прострочений snooze автоматично
  /// вважається неактивним (але без побічного очищення поля — це робить
  /// лише [evaluate] / [activateSnooze], щоб не було прихованих мутацій
  /// у геттері).
  bool _isSnoozedAt(DateTime now) {
    final until = _snoozeUntil;
    if (until == null) return false;
    return now.isBefore(until);
  }

  /// Основний виклик — передати нові дані телеметрії й отримати рішення.
  ///
  /// [now] можна передати явно для детермінованих тестів; за замовчуванням
  /// береться поточний час.
  AlarmEvaluation evaluate({
    required int soc,
    required bool isCharging,
    required int lowThreshold,
    required int fullThreshold,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    AlarmAudioAction action = AlarmAudioAction.none;

    // Прострочений snooze більше не діє.
    if (_snoozeUntil != null && !now.isBefore(_snoozeUntil!)) {
      _snoozeUntil = null;
    }

    final bool fullCondition = soc >= fullThreshold && isCharging;
    final bool lowCondition = !isCharging && soc <= lowThreshold;
    final bool conditionMet = fullCondition || lowCondition;

    // Умова, що тримала паузу "актуальною", щойно зникла -> паузу знімаємо
    // достроково, навіть якщо тривога весь цей час мовчала через snooze.
    if (_wasAlarmConditionMet && !conditionMet) {
      _snoozeUntil = null;
    }
    _wasAlarmConditionMet = conditionMet;

    final bool snoozed = _isSnoozedAt(now);

    if (fullCondition) {
      if (_isLowAlarmActive) {
        _isLowAlarmActive = false;
        action = AlarmAudioAction.stop;
      }
      if (!_isFullAlarmActive && !snoozed) {
        _isFullAlarmActive = true;
        action = AlarmAudioAction.playFull;
      }
      return _snapshot(action,
          lowConditionMet: lowCondition, fullConditionMet: fullCondition, now: now);
    }

    if (_isFullAlarmActive) {
      _isFullAlarmActive = false;
      action = AlarmAudioAction.stop;
    }

    if (isCharging) {
      if (_isLowAlarmActive) {
        _isLowAlarmActive = false;
        action = AlarmAudioAction.stop;
      }
      return _snapshot(action,
          lowConditionMet: lowCondition, fullConditionMet: fullCondition, now: now);
    }

    if (lowCondition) {
      if (!_isLowAlarmActive && !snoozed) {
        _isLowAlarmActive = true;
        action = AlarmAudioAction.playLow;
      }
    } else if (_isLowAlarmActive) {
      _isLowAlarmActive = false;
      action = AlarmAudioAction.stop;
    }

    return _snapshot(action,
        lowConditionMet: lowCondition, fullConditionMet: fullCondition, now: now);
  }

  /// Ручна призупинка (кнопка "Заглушити сигнал" / snooze у нотифікації).
  /// Гасить будь-яку поточну тривогу і вмикає паузу на [duration].
  ///
  /// [AlarmEvaluation.lowConditionMet]/[AlarmEvaluation.fullConditionMet] у
  /// поверненому знімку відображають, яка саме тривога (якщо була) щойно
  /// заглушена — цей метод не знає поточних `soc`/`isCharging`, тому не може
  /// перевірити умову заново; наступний [evaluate] з реальними даними
  /// перерахує їх точно.
  AlarmEvaluation activateSnooze(Duration duration, {DateTime? now}) {
    now ??= DateTime.now();
    _snoozeUntil = now.add(duration);

    final bool wasLowRinging = _isLowAlarmActive;
    final bool wasFullRinging = _isFullAlarmActive;
    _isLowAlarmActive = false;
    _isFullAlarmActive = false;

    return _snapshot(
      (wasLowRinging || wasFullRinging)
          ? AlarmAudioAction.stop
          : AlarmAudioAction.none,
      lowConditionMet: wasLowRinging,
      fullConditionMet: wasFullRinging,
      now: now,
    );
  }

  /// Скільки хвилин лишилось до кінця паузи (округлення вгору), або 0.
  int remainingSnoozeMinutes(DateTime now) {
    final until = _snoozeUntil;
    if (until == null || !now.isBefore(until)) return 0;
    return until.difference(now).inMinutes + 1;
  }

  AlarmEvaluation _snapshot(
    AlarmAudioAction action, {
    required bool lowConditionMet,
    required bool fullConditionMet,
    required DateTime now,
  }) =>
      AlarmEvaluation(
        audioAction: action,
        isLowAlarmActive: _isLowAlarmActive,
        isFullAlarmActive: _isFullAlarmActive,
        isSnoozed: _snoozeUntil != null,
        lowConditionMet: lowConditionMet,
        fullConditionMet: fullConditionMet,
        remainingSnoozeMinutes: remainingSnoozeMinutes(now),
      );
}
