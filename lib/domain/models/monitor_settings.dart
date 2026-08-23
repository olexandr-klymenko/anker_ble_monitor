/// Пороги й параметри моніторингу, якими користувач керує з UI.
///
/// Раніше ці три значення передавались окремо як `Map<String, int>` —
/// причому ключі різнились між сховищем (`lowThreshold`) і IPC-повідомленням
/// до фонового ізолята (`threshold`), що й спричиняло мовчазні розбіжності.
/// Єдиний value-object з фіксованими полями прибирає цей клас багів: одруківка
/// в назві ключа тепер не компілюється.
class MonitorSettings {
  final int lowThreshold;
  final int fullThreshold;
  final int snoozeMinutes;

  const MonitorSettings({
    required this.lowThreshold,
    required this.fullThreshold,
    required this.snoozeMinutes,
  });

  static const MonitorSettings defaults = MonitorSettings(
    lowThreshold: 15,
    fullThreshold: 100,
    snoozeMinutes: 3,
  );

  Map<String, dynamic> toJson() => {
        'lowThreshold': lowThreshold,
        'fullThreshold': fullThreshold,
        'snoozeMinutes': snoozeMinutes,
      };

  /// Читає поля з мапи, підставляючи [defaults] для будь-якого відсутнього
  /// чи хибно типізованого значення — так само, як раніше поводились окремі
  /// `prefs.getInt(...) ?? ...` виклики в сховищі.
  factory MonitorSettings.fromJson(Map<dynamic, dynamic> json) {
    return MonitorSettings(
      lowThreshold: _readInt(json['lowThreshold'], defaults.lowThreshold),
      fullThreshold: _readInt(json['fullThreshold'], defaults.fullThreshold),
      snoozeMinutes: _readInt(json['snoozeMinutes'], defaults.snoozeMinutes),
    );
  }

  static int _readInt(dynamic value, int fallback) =>
      value is int ? value : fallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitorSettings &&
          runtimeType == other.runtimeType &&
          lowThreshold == other.lowThreshold &&
          fullThreshold == other.fullThreshold &&
          snoozeMinutes == other.snoozeMinutes;

  @override
  int get hashCode => Object.hash(lowThreshold, fullThreshold, snoozeMinutes);

  @override
  String toString() => 'MonitorSettings(low: $lowThreshold%, '
      'full: $fullThreshold%, snooze: $snoozeMinutes хв)';
}
