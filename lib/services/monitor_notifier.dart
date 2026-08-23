import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../domain/monitor_notification_builder.dart';

/// Абстракція над показом фонової нотифікації. Дозволяє [MonitorService]
/// лишатись тестованим без реального `flutter_foreground_task` сервісу.
abstract class MonitorNotifier {
  /// Показує вміст, побудований [MonitorNotificationBuilder].
  void show(MonitorNotificationContent content);

  /// Особливий випадок поза звичайним циклом тривоги: реальний BLE-розрив
  /// з'єднання (не невдала спроба підключення — та обробляється мовчки й
  /// повторюється наступним тіком).
  void showConnectionLost();
}

class ForegroundTaskMonitorNotifier implements MonitorNotifier {
  @override
  void show(MonitorNotificationContent content) {
    FlutterForegroundTask.updateService(
      notificationTitle: content.title,
      notificationText: content.text,
      notificationButtons: content.showSnoozeButton
          ? const [
              NotificationButton(id: 'btn_snooze', text: 'Заглушити сигнал'),
            ]
          : const [],
    );
  }

  @override
  void showConnectionLost() {
    FlutterForegroundTask.updateService(
      notificationTitle: 'Anker Monitor',
      notificationText: 'Зв\'язок втрачено. Очікування...',
      notificationButtons: const [],
    );
  }
}
