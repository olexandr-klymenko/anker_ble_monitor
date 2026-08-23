import 'package:audioplayers/audioplayers.dart';

/// Абстракція над відтворенням звуку тривоги. Дозволяє [MonitorService]
/// лишатись тестованим без реального аудіоплеєра (платформного плагіна).
abstract class AlarmAudio {
  /// Зупиняє поточний звук (якщо є) і починає програвати [assetPath] у циклі.
  Future<void> playLoop(String assetPath);

  /// Зупиняє поточний звук.
  Future<void> stop();

  /// Звільняє ресурси плеєра.
  Future<void> dispose();
}

class AudioPlayersAlarmAudio implements AlarmAudio {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playLoop(String assetPath) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource(assetPath));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
