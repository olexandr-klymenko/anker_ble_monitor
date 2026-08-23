import 'package:flutter_test/flutter_test.dart';
import 'package:anker_ble_monitor/domain/models/monitor_settings.dart';
import 'package:anker_ble_monitor/services/monitor_service.dart';
import '../fakes/fake_alarm_audio.dart';
import '../fakes/fake_anker_connection.dart';
import '../fakes/fake_monitor_notifier.dart';

const _settings = MonitorSettings(
  lowThreshold: 15,
  fullThreshold: 100,
  snoozeMinutes: 3,
);

void main() {
  late FakeAnkerConnection connection;
  late FakeAlarmAudio audio;
  late FakeMonitorNotifier notifier;
  late MonitorService service;

  setUp(() {
    connection = FakeAnkerConnection();
    audio = FakeAlarmAudio();
    notifier = FakeMonitorNotifier();
    service = MonitorService(
      connection: connection,
      audio: audio,
      notifier: notifier,
      settings: _settings,
    );
  });

  group('MonitorService.start', () {
    test('з переданим deviceId одразу підключається', () {
      service.start('AA:BB:CC:11:22:33');

      expect(connection.connectCalls, ['AA:BB:CC:11:22:33']);
    });

    test('без збереженого пристрою (null/порожній) не намагається '
        'підключитись', () {
      service.start(null);
      service.start('');

      expect(connection.connectCalls, isEmpty);
    });
  });

  group('MonitorService — телеметрія й публікація в UI', () {
    test('нова телеметрія викликає onTelemetry з коректним soc/isCharging',
        () {
      service.start('AA:BB:CC:11:22:33');
      final published = <bool>[];
      service.onTelemetry = (t) => published.add(t.isAlarmRinging);

      connection.emitTelemetry(soc: 50, isCharging: false);

      expect(published, [false]);
    });

    test('низький заряд без зарядки -> AlarmAudio.playLoop("alarm_clock.ogg") '
        'і onTelemetry.isAlarmRinging=true', () {
      service.start('AA:BB:CC:11:22:33');
      bool? ringing;
      service.onTelemetry = (t) => ringing = t.isAlarmRinging;

      connection.emitTelemetry(soc: 10, isCharging: false);

      expect(audio.currentlyPlaying, 'audio/alarm_clock.ogg');
      expect(ringing, isTrue);
      expect(notifier.last?.showSnoozeButton, isTrue);
    });

    test('повний заряд під час зарядки -> AlarmAudio.playLoop("full_charge.ogg")',
        () {
      service.start('AA:BB:CC:11:22:33');

      connection.emitTelemetry(soc: 100, isCharging: true);

      expect(audio.currentlyPlaying, 'audio/full_charge.ogg');
      expect(notifier.last?.title, contains('🔋'));
    });
  });

  group('MonitorService — повний сценарій: тривога -> пауза -> тиша', () {
    test('12% без зарядки дзвонить, snooze() глушить звук і лишає паузу '
        'на повторній такій самій телеметрії', () {
      service.start('AA:BB:CC:11:22:33');

      // 1. Телеметрія 12% без зарядки -> тривога дзвонить.
      connection.emitTelemetry(soc: 12, isCharging: false);
      expect(audio.currentlyPlaying, 'audio/alarm_clock.ogg');
      expect(notifier.last?.showSnoozeButton, isTrue);

      // 2. Користувач тисне "Заглушити" -> звук зупинено, нотифікація паузи.
      service.snooze();
      expect(audio.currentlyPlaying, isNull);
      expect(notifier.last?.title, contains('🔕 Пауза'));
      expect(notifier.last?.showSnoozeButton, isFalse);

      // 3. Той самий 12% знову приходить -> тривога НЕ повертається (пауза
      // ще активна), звук лишається тихим.
      bool? ringingAfterSnooze;
      service.onTelemetry = (t) => ringingAfterSnooze = t.isAlarmRinging;
      connection.emitTelemetry(soc: 12, isCharging: false);

      expect(audio.currentlyPlaying, isNull);
      expect(ringingAfterSnooze, isFalse);
      expect(notifier.last?.title, contains('🔕 Пауза'));
    });

    test('snooze() без телеметрії (soc ще невідомий) не показує нотифікацію',
        () {
      service.start('AA:BB:CC:11:22:33');

      service.snooze();

      expect(notifier.shown, isEmpty);
    });
  });

  group('MonitorService.updateSettings', () {
    test('без телеметрії лише зберігає нові налаштування, нічого не '
        'перераховує', () {
      service.start('AA:BB:CC:11:22:33');

      service.updateSettings(
          const MonitorSettings(lowThreshold: 30, fullThreshold: 90, snoozeMinutes: 5));

      expect(service.settings.lowThreshold, 30);
      expect(notifier.shown, isEmpty);
    });

    test('з наявною телеметрією одразу перераховує тривогу під нові пороги',
        () {
      service.start('AA:BB:CC:11:22:33');
      connection.emitTelemetry(soc: 25, isCharging: false); // > 15, тиша

      expect(audio.currentlyPlaying, isNull);

      // Піднімаємо lowThreshold до 30 -> 25% тепер під порогом.
      service.updateSettings(
          const MonitorSettings(lowThreshold: 30, fullThreshold: 100, snoozeMinutes: 3));

      expect(audio.currentlyPlaying, 'audio/alarm_clock.ogg');
    });
  });

  group('MonitorService.selectDevice', () {
    test('той самий deviceId -> нічого не робить', () async {
      service.start('AA:BB:CC:11:22:33');
      connection.connectCalls.clear();

      await service.selectDevice('AA:BB:CC:11:22:33');

      expect(connection.connectCalls, isEmpty);
      expect(connection.disconnectCalls, 0);
    });

    test('інший deviceId -> розриває поточне і підключається до нового', () async {
      service.start('AA:BB:CC:11:22:33');

      await service.selectDevice('DD:EE:FF:44:55:66');

      expect(connection.disconnectCalls, 1);
      expect(connection.connectCalls.last, 'DD:EE:FF:44:55:66');
    });
  });

  group('MonitorService — тік (keep-alive / перепідключення)', () {
    test('коли підключено -> надсилає keep-alive', () {
      service.start('AA:BB:CC:11:22:33'); // autoConnectSucceeds за замовч.

      service.tick();

      expect(connection.keepAliveCalls, 1);
    });

    test('коли не підключено -> намагається перепідключитись', () {
      connection.autoConnectSucceeds = false;
      service.start('AA:BB:CC:11:22:33');
      connection.connectCalls.clear();

      service.tick();

      expect(connection.connectCalls, ['AA:BB:CC:11:22:33']);
      expect(connection.keepAliveCalls, 0);
    });
  });

  group('MonitorService — реальний розрив з\'єднання', () {
    test('dropConnection() (подія BLE-стека) показує "зв\'язок втрачено"',
        () {
      service.start('AA:BB:CC:11:22:33');

      connection.dropConnection();

      expect(notifier.connectionLostCalls, 1);
    });
  });

  group('MonitorService.dispose', () {
    test('звільняє і з\'єднання, і аудіо', () async {
      service.start('AA:BB:CC:11:22:33');

      await service.dispose();

      expect(connection.disposed, isTrue);
      expect(audio.disposed, isTrue);
    });
  });
}
