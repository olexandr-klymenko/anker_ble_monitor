import 'alarm_controller.dart';
import 'models/monitor_settings.dart';

/// Текст і заголовок фонової нотифікації + чи показувати кнопку "Заглушити".
///
/// Не залежить від Flutter — [AnkerBackgroundTaskHandler] сам відображає
/// це через `FlutterForegroundTask.updateService`.
class MonitorNotificationContent {
  final String title;
  final String text;
  final bool showSnoozeButton;

  const MonitorNotificationContent({
    required this.title,
    required this.text,
    required this.showSnoozeButton,
  });

  @override
  String toString() => 'MonitorNotificationContent(title: $title, '
      'text: $text, showSnoozeButton: $showSnoozeButton)';
}

/// Будує вміст нотифікації виключно зі знімка [AlarmEvaluation] — жодного
/// повторного порівняння `soc` з порогами тут немає, усі умови тривоги вже
/// пораховані [AlarmController]. Це усуває клас багів, коли фонова
/// нотифікація й реальний стан тривоги розходились через два незалежні
/// обчислення однієї й тієї ж умови.
class MonitorNotificationBuilder {
  const MonitorNotificationBuilder._();

  static MonitorNotificationContent build({
    required AlarmEvaluation evaluation,
    required MonitorSettings settings,
    required int soc,
    required bool isCharging,
  }) {
    if (evaluation.isLowAlarmActive) {
      return MonitorNotificationContent(
        title: 'Anker: $soc% (⚠️ Низький заряд)',
        text: 'Низький заряд батареї (<= ${settings.lowThreshold}%)!',
        showSnoozeButton: true,
      );
    }

    if (evaluation.isFullAlarmActive) {
      return MonitorNotificationContent(
        title: 'Anker: $soc% (🔋 Заряджено!)',
        text: 'Досягнуто ${settings.fullThreshold}%. Вимкніть генератор!',
        showSnoozeButton: true,
      );
    }

    if (evaluation.conditionMet && evaluation.isSnoozed) {
      final String text = isCharging
          ? '⚡ Досягнуто ${settings.fullThreshold}%. Звук заглушено на '
              '${evaluation.remainingSnoozeMinutes} хв'
          : '⚠️ Низький заряд (<= ${settings.lowThreshold}%). Звук заглушено '
              'на ${evaluation.remainingSnoozeMinutes} хв';
      return MonitorNotificationContent(
        title: 'Anker: $soc% (🔕 Пауза)',
        text: text,
        showSnoozeButton: false,
      );
    }

    if (isCharging) {
      return MonitorNotificationContent(
        title: 'Anker: $soc% (⚡ Заряджається)',
        text: 'Живлення підключено.',
        showSnoozeButton: false,
      );
    }

    return MonitorNotificationContent(
      title: 'Anker: $soc%',
      text: 'Заряд під контролем (поріг: ${settings.lowThreshold}%)',
      showSnoozeButton: false,
    );
  }
}
