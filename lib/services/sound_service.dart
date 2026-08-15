import 'package:audioplayers/audioplayers.dart';

/// Plays short UI sounds.
class SoundService {
  SoundService._();

  static final AudioPlayer _player = AudioPlayer();

  /// Plays the guitar-style success sound on order placement.
  static Future<void> playOrderSuccess() async {
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/order_success.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Ignore playback errors (e.g. asset not available on a platform).
    }
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
