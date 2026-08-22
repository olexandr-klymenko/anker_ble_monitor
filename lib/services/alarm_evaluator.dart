enum AlarmType { none, low, full }

enum AlarmAction {
  none,
  startLow,
  startFull,
  stop,
}

class AlarmEvaluator {
  int lowThreshold;
  int fullThreshold;

  bool isLowAlarmActive = false;
  bool isFullAlarmActive = false;

  AlarmEvaluator({
    this.lowThreshold = 15,
    this.fullThreshold = 100,
  });

  /// Обчислює новий стан та повертає необхідну дію для аудіо/сповіщень.
  AlarmAction evaluate({
    required int soc,
    required bool isChargingFromAC,
    required bool isSnoozed,
  }) {
    // 1. Повна зарядка (SOC >= fullThreshold)
    if (soc >= fullThreshold) {
      if (isLowAlarmActive) {
        isLowAlarmActive = false;
      }

      if (!isFullAlarmActive && !isSnoozed) {
        isFullAlarmActive = true;
        return AlarmAction.startFull;
      }
      return AlarmAction.none;
    }

    // Скидаємо аларм повного заряду ТІЛЬКИ якщо генератор вимкнули ДО досягнення 100%
    if (isFullAlarmActive && !isChargingFromAC) {
      isFullAlarmActive = false;
      return AlarmAction.stop;
    }

    // 2. Звичайний процес зарядки (<100%)
    if (isChargingFromAC) {
      if (isLowAlarmActive) {
        isLowAlarmActive = false;
        return AlarmAction.stop;
      }
      return AlarmAction.none;
    }

    // 3. Низький заряд
    if (soc <= lowThreshold) {
      if (!isLowAlarmActive && !isSnoozed) {
        if (isFullAlarmActive) isFullAlarmActive = false;
        isLowAlarmActive = true;
        return AlarmAction.startLow;
      }
    } else {
      if (isLowAlarmActive) {
        isLowAlarmActive = false;
        return AlarmAction.stop;
      }
    }

    return AlarmAction.none;
  }

  void resetAll() {
    isLowAlarmActive = false;
    isFullAlarmActive = false;
  }
}