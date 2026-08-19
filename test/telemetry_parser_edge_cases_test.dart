import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/services/telemetry_parser.dart';

void main() {
  group('TelemetryParser Edge Cases & Boundary Tests', () {
    test('Should accept boundary SOC values (0% and 100%)', () {
      final bytes = List<int>.filled(125, 0);

      // 0% SOC
      bytes[70] = 0;
      var result = TelemetryParser.parse(bytes);
      expect(result, isNotNull);
      expect(result!.soc, equals(0));

      // 100% SOC
      bytes[70] = 100;
      result = TelemetryParser.parse(bytes);
      expect(result, isNotNull);
      expect(result!.soc, equals(100));
    });

    test('Should correctly calculate 16-bit rawAcIn across two bytes', () {
      final bytes = List<int>.filled(125, 0);
      bytes[70] = 50;

      // rawAcIn threshold boundary test (rawAcIn > 10)
      // byte 18 = 10, byte 19 = 0 -> rawAcIn = 10 (isCharging = false)
      bytes[18] = 10;
      bytes[19] = 0;
      var result = TelemetryParser.parse(bytes);
      expect(result!.isCharging, isFalse);

      // byte 18 = 11, byte 19 = 0 -> rawAcIn = 11 (isCharging = true)
      bytes[18] = 11;
      bytes[19] = 0;
      result = TelemetryParser.parse(bytes);
      expect(result!.isCharging, isTrue);

      // High byte test: byte 18 = 0, byte 19 = 1 -> rawAcIn = 256 (isCharging = true)
      bytes[18] = 0;
      bytes[19] = 1;
      result = TelemetryParser.parse(bytes);
      expect(result!.isCharging, isTrue);
    });
  });
}
