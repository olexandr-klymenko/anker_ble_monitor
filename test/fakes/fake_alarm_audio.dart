import 'package:anker_ble_monitor/services/alarm_audio.dart';

class FakeAlarmAudio implements AlarmAudio {
  final List<String> playLoopCalls = [];
  int stopCalls = 0;
  bool disposed = false;

  /// Асет, що зараз "грає" — `null`, якщо звук зупинено.
  String? currentlyPlaying;

  @override
  Future<void> playLoop(String assetPath) async {
    playLoopCalls.add(assetPath);
    currentlyPlaying = assetPath;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    currentlyPlaying = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
