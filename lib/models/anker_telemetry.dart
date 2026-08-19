class AnkerTelemetry {
  final bool isAlarmRinging;
  final int soc; // Відсоток заряду (0-100)
  final int acInWatts; // Залишено для сумісності
  final bool isCharging;

  AnkerTelemetry({
    required this.isAlarmRinging,
    required this.soc,
    required this.acInWatts,
    required this.isCharging,
  });

  Map<String, dynamic> toJson() => {
        'isAlarmRinging': isAlarmRinging,
        'soc': soc,
        'acInWatts': acInWatts,
        'isCharging': isCharging,
      };

  factory AnkerTelemetry.fromJson(Map<String, dynamic> json) {
    return AnkerTelemetry(
      isAlarmRinging: json['isAlarmRinging'] as bool? ?? false,
      soc: json['soc'] as int? ?? -1,
      acInWatts: json['acInWatts'] as int? ?? 0,
      isCharging: json['isCharging'] as bool? ?? false,
    );
  }
}