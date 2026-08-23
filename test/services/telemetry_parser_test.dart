import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/models/anker_telemetry.dart';
import 'package:anker_ble_monitor/services/telemetry_parser.dart';

void main() {
  group('TelemetryParser Unit Tests', () {
    test('Should return null when byte array is shorter than minPacketLength',
        () {
      final shortBytes =
          List<int>.filled(TelemetryParser.minPacketLength - 1, 0);
      final result = TelemetryParser.parse(shortBytes);
      expect(result, isNull);
    });

    test('Should parse SOC percentage correctly from socByteIndex', () {
      final bytes = List<int>.filled(125, 0);
      bytes[TelemetryParser.socByteIndex] = 85; // 85% SOC
      bytes[TelemetryParser.acInLowByteIndex] = 0; // No AC input
      bytes[TelemetryParser.acInHighByteIndex] = 0;

      final result = TelemetryParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.soc, equals(85));
      expect(result.isCharging, isFalse);
    });

    test('Should detect AC charging state when rawAcIn > acInChargingThreshold',
        () {
      final bytes = List<int>.filled(125, 0);
      bytes[TelemetryParser.socByteIndex] = 50;
      // rawAcIn = low | ((high & 0xFF) << 8)
      bytes[TelemetryParser.acInLowByteIndex] = 20; // > acInChargingThreshold
      bytes[TelemetryParser.acInHighByteIndex] = 0;

      final result = TelemetryParser.parse(bytes);

      expect(result, isNotNull);
      expect(result!.soc, equals(50));
      expect(result.isCharging, isTrue);
    });

    test('Should return null if SOC value is invalid (< 0 or > 100)', () {
      final bytes = List<int>.filled(125, 0);
      bytes[TelemetryParser.socByteIndex] = 105; // Invalid SOC > 100%

      final result = TelemetryParser.parse(bytes);
      expect(result, isNull);
    });
  });

  group('AnkerTelemetry Serialization Tests', () {
    test('Should correctly serialize to and deserialize from JSON', () {
      final telemetry = AnkerTelemetry(
        isAlarmRinging: true,
        soc: 15,
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
