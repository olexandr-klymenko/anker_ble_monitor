import '../domain/models/monitor_settings.dart';

/// Команди, які UI-ізолят надсилає фоновому через
/// `FlutterForegroundTask.sendDataToTask`.
///
/// Раніше [AnkerBackgroundTaskHandler.onReceiveData] вручну перевіряв
/// `containsKey`/`is int` для чотирьох довільних ключів у сирій `Map` —
/// це не давало компілятору жодної гарантії, що відправник і отримувач
/// узгоджені. Sealed-ієрархія робить набір команд закритим і дозволяє
/// вичерпний `switch` без `default`.
sealed class MonitorCommand {
  const MonitorCommand();

  Map<String, dynamic> toJson();

  /// Повертає `null`, якщо [data] не є розпізнаваною командою (невідомий чи
  /// відсутній `type`) — виклики просто ігнорують такі повідомлення.
  static MonitorCommand? fromJson(Object? data) {
    if (data is! Map) return null;

    switch (data['type']) {
      case 'syncState':
        final rawSettings = data['settings'];
        final deviceId = data['deviceId'];
        if (rawSettings is! Map || deviceId is! String) return null;
        return SyncStateCommand(
          deviceId: deviceId,
          settings: MonitorSettings.fromJson(rawSettings),
        );
      case 'snooze':
        return const SnoozeCommand();
      default:
        return null;
    }
  }
}

/// Обраний пристрій і поточні пороги/пауза — надсилається разом одним
/// повідомленням, бо саме так їх завжди міняє UI (вибір пристрою чи
/// збереження налаштувань завжди супроводжується повним станом).
class SyncStateCommand extends MonitorCommand {
  final String deviceId;
  final MonitorSettings settings;

  const SyncStateCommand({required this.deviceId, required this.settings});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'syncState',
        'deviceId': deviceId,
        'settings': settings.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStateCommand &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          settings == other.settings;

  @override
  int get hashCode => Object.hash(deviceId, settings);
}

/// Ручна призупинка тривоги (кнопка в UI-застосунку).
class SnoozeCommand extends MonitorCommand {
  const SnoozeCommand();

  @override
  Map<String, dynamic> toJson() => {'type': 'snooze'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SnoozeCommand;

  @override
  int get hashCode => runtimeType.hashCode;
}
