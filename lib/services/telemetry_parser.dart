class TelemetryParseResult {
  final int soc;
  final bool isCharging;

  TelemetryParseResult({required this.soc, required this.isCharging});
}

/// Парсер сирих BLE-пакетів телеметрії станції Anker PowerHouse.
///
/// Офіційної специфікації протоколу немає — усі зміщення байтів нижче
/// визначені емпірично (реверс-інжиніринг трафіку офіційного застосунку).
/// Якщо після оновлення прошивки станції парсинг почне повертати `null`
/// або хибні значення — перевіряти варто саме ці константи.
class TelemetryParser {
  /// Мінімальна довжина пакета, за якої взагалі має сенс шукати потрібні
  /// байти. Пакети коротші за це відкидаються як непридатні для парсингу.
  static const int minPacketLength = 122;

  /// Індекс байта з відсотком заряду (State of Charge), значення 0-100.
  static const int socByteIndex = 70;

  /// Індекс молодшого байта 16-бітного "сирого" значення потужності
  /// AC-входу (little-endian: rawAcIn = low | (high << 8)).
  static const int acInLowByteIndex = 18;

  /// Індекс старшого байта того ж 16-бітного значення AC-входу.
  static const int acInHighByteIndex = 19;

  /// Поріг "сирого" значення AC-входу, вище якого вважаємо, що станція
  /// отримує живлення від мережі/генератора. Підібраний емпірично, щоб
  /// відсікти фоновий шум лінії при вимкненій зарядці (сирі 0-10 — це шум,
  /// не реальна потужність).
  static const int acInChargingThreshold = 10;

  static const int _minValidSoc = 0;
  static const int _maxValidSoc = 100;

  /// Парсить байтовий масив від Anker BLE і повертає відсоток заряду та
  /// стан зарядки від мережі, або `null`, якщо пакет закороткий чи містить
  /// явно невалідний SOC.
  static TelemetryParseResult? parse(List<int> bytes) {
    if (bytes.length < minPacketLength) return null;

    final int soc = bytes[socByteIndex];
    if (soc < _minValidSoc || soc > _maxValidSoc) return null;

    final int rawAcIn =
        bytes[acInLowByteIndex] | ((bytes[acInHighByteIndex] & 0xFF) << 8);
    final bool isCharging = rawAcIn > acInChargingThreshold;

    return TelemetryParseResult(soc: soc, isCharging: isCharging);
  }
}
