import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Looping background music, kept separate from [SoundService] (which only
/// deals in one-shot [AudioPool] effects) since `FlameAudio.bgm` is a
/// different mechanism — a single lifecycle-aware looping player that
/// auto-pauses when the app is backgrounded.
///
/// Both tracks are procedurally synthesised by `tool/gen_music.js` —
/// regenerate from there rather than hand-editing the WAVs.
///
/// Has its own on/off toggle, independent of [SoundService]'s effects
/// toggle.
class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  static const _menuTrack = 'bgm_menu.wav';
  static const _gameTrack = 'bgm_game.wav';
  static const _volume = 0.4;
  static const _enabledKey = 'nm_music_enabled';

  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  String? _wanted;
  bool _initialized = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {}
    try {
      // Same no-audio-focus context SoundService sets globally, passed
      // explicitly too: both inits run unawaited with no guaranteed order,
      // and FlameAudio.bgm otherwise locks in its own default context the
      // first time it's referenced — with focus taken, every SFX would
      // pause this loop on Android.
      await FlameAudio.bgm.initialize(
        audioContext: AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      _initialized = true;
      // MenuScreen usually asks for its track before this init (fired
      // unawaited from main) finishes — start it now or first launch is
      // silent.
      final pending = _wanted;
      if (pending != null) _play(pending);
    } catch (_) {
      // No music this session — the game stays fully playable in silence.
    }
  }

  void playMenu() => _play(_menuTrack);

  void playGame() => _play(_gameTrack);

  void _play(String track) {
    _wanted = track;
    if (!_initialized || !enabledNotifier.value) return;
    // Safe to call while another track plays — it replaces the source.
    FlameAudio.bgm.play(track, volume: _volume).catchError((_) {});
  }

  Future<void> toggle() async {
    enabledNotifier.value = !enabledNotifier.value;
    if (_initialized && _wanted != null) {
      if (enabledNotifier.value) {
        FlameAudio.bgm.play(_wanted!, volume: _volume).catchError((_) {});
      } else {
        FlameAudio.bgm.stop().catchError((_) {});
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabledNotifier.value);
    } catch (_) {}
  }
}
