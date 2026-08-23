import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/services/telemetry_parser.dart';

void main() {
  group('TelemetryParser Edge Cases & Boundary Tests', () {
    test('Should accept boundary SOC values (0% and 100%)', () {
      final bytes = List<int>.filled(125, 0);

      // 0% SOC
      bytes[TelemetryParser.socByteIndex] = 0;
      var result = TelemetryParser.parse(bytes);
      expect(result, isNotNull);
      expect(result!.soc, equals(0));

      // 100% SOC
      bytes[TelemetryParser.socByteIndex] = 100;
      result = TelemetryParser.parse(bytes);
      expect(result, isNotNull);
      expect(result!.soc, equals(100));
    });

    test('Should correctly calculate 16-bit rawAcIn across two bytes', () {
      final bytes = List<int>.filled(125, 0);
      bytes[TelemetryParser.socByteIndex] = 50;

      // rawAcIn threshold boundary test (rawAcIn > acInChargingThreshold)
      // low = 10, high = 0 -> rawAcIn = 10 (isCharging = false)
      bytes[TelemetryParser.acInLowByteIndex] = 10;
      bytes[TelemetryParser.acInHighByteIndex] = 0;
      var result = TelemetryParser.parse(bytes);
      expect(result!.isCharging, isFalse);

      // low = 11, high = 0 -> rawAcIn = 11 (isCharging = true)
      bytes[TelemetryParser.acInLowByteIndex] = 11;
      bytes[TelemetryParser.acInHighByteIndex] = 0;
      result = TelemetryParser.parse(bytes);
      expect(result!.isCharging, isTrue);

      // High byte test: low = 0, high = 1 -> rawAcIn = 256 (isCharging = true)
      bytes[TelemetryParser.acInLowByteIndex] = 0;
      bytes[TelemetryParser.acInHighByteIndex] = 1;
      result = TelemetryParser.parse(bytes);
      expect(result!.isCharging, isTrue);
    });

    test('Should reject packets shorter than minPacketLength', () {
      final bytes = List<int>.filled(TelemetryParser.minPacketLength - 1, 0);
      final result = TelemetryParser.parse(bytes);
      expect(result, isNull);
    });

    test('Should accept packets exactly at minPacketLength', () {
      final bytes = List<int>.filled(TelemetryParser.minPacketLength, 0);
      bytes[TelemetryParser.socByteIndex] = 42;
      final result = TelemetryParser.parse(bytes);
      expect(result, isNotNull);
      expect(result!.soc, equals(42));
    });
  });
}
