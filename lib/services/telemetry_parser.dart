class TelemetryParseResult {
  final int soc;
  final bool isCharging;

  TelemetryParseResult({required this.soc, required this.isCharging});
}

class TelemetryParser {
  /// Парсить байтовий масив від Anker BLE і повертає відсоток та стан живлення
  static TelemetryParseResult? parse(List<int> bytes) {
    if (bytes.length < 122) return null;

    int soc = bytes[70];
    if (soc < 0 || soc > 100) return null;

    int rawAcIn = bytes[18] | ((bytes[19] & 0xFF) << 8);
    bool isCharging = rawAcIn > 10;

    return TelemetryParseResult(soc: soc, isCharging: isCharging);
  }
}
