import 'package:anker_ble_monitor/domain/monitor_notification_builder.dart';
import 'package:anker_ble_monitor/services/monitor_notifier.dart';

class FakeMonitorNotifier implements MonitorNotifier {
  final List<MonitorNotificationContent> shown = [];
  int connectionLostCalls = 0;

  MonitorNotificationContent? get last => shown.isEmpty ? null : shown.last;

  @override
  void show(MonitorNotificationContent content) {
    shown.add(content);
  }

  @override
  void showConnectionLost() {
    connectionLostCalls++;
  }
}
