import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/models/anker_telemetry.dart';
import 'package:anker_ble_monitor/services/telemetry_parser.dart';

void main() {
  group('TelemetryParser Unit Tests', () {
    test('Should return null when byte array length is less than 122', () {
      final shortBytes = List<int>.filled(100, 0);
      final result = TelemetryParser.parse(shortBytes);
      expect(result, isNull);
    });

    test('Should parse SOC percentage correctly from byte index 70', () {
      final bytes = List<int>.filled(125, 0);
      bytes[70] = 85; // 85% SOC
      bytes[18] = 0;  // No AC input
      bytes[19] = 0;

      final result = TelemetryParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.soc, equals(85));
      expect(result.isCharging, isFalse);
    });

    test('Should detect AC charging state when rawAcIn > 10', () {
      final bytes = List<int>.filled(125, 0);
      bytes[70] = 50;
      // rawAcIn = bytes[18] | ((bytes[19] & 0xFF) << 8)
      bytes[18] = 20; // > 10
      bytes[19] = 0;

      final result = TelemetryParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.soc, equals(50));
      expect(result.isCharging, isTrue);
    });

    test('Should return null if SOC value is invalid (< 0 or > 100)', () {
      final bytes = List<int>.filled(125, 0);
      bytes[70] = 105; // Invalid SOC > 100%

      final result = TelemetryParser.parse(bytes);
      expect(result, isNull);
    });
  });

  group('AnkerTelemetry Serialization Tests', () {
    test('Should correctly serialize to and deserialize from JSON', () {
      final telemetry = AnkerTelemetry(
        isAlarmRinging: true,
        soc: 15,
        acInWatts: 0,
        isCharging: false,
      );

      final json = telemetry.toJson();
      final deserialized = AnkerTelemetry.fromJson(json);

      expect(deserialized.isAlarmRinging, isTrue);
      expect(deserialized.soc, equals(15));
      expect(deserialized.isCharging, isFalse);
    });
  });
}