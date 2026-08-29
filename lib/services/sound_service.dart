import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SfxEvent {
  swipe('swipe.wav'),
  gateGood('gate_good.wav'),
  gateBad('gate_bad.wav'),
  absorb('absorb.wav'),
  death('death.wav'),
  wallBreak('wall_break.wav'),
  levelComplete('level_complete.wav'),
  buttonTap('button_tap.wav');

  const SfxEvent(this.fileName);
  final String fileName;
}

/// Wraps flame_audio's AudioPool — never plain AudioPlayer, which has a
/// known leak/delay bug on this stack. Safe to ship with zero or partial
/// WAV files under assets/audio/: every load is try/catch-guarded so a
/// missing file just silently no-ops instead of crashing.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _prefsKey = 'nm_sound_enabled';

  final ValueNotifier<bool> enabledNotifier = ValueNotifier(true);
  final Map<SfxEvent, AudioPool> _pools = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    enabledNotifier.value = prefs.getBool(_prefsKey) ?? true;

    for (final event in SfxEvent.values) {
      try {
        // A missing/invalid asset can leave the underlying platform
        // Future hanging rather than rejecting on some browsers, so a
        // hard timeout is needed on top of the try/catch — otherwise one
        // bad file could stall every event after it in this loop.
        _pools[event] = await FlameAudio.createPool(
          event.fileName,
          maxPlayers: 3,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Missing/invalid asset — this event just won't play. Fine for
        // early builds before real SFX are supplied.
      }
    }
  }

  void play(SfxEvent event) {
    if (!enabledNotifier.value) return;
    try {
      _pools[event]?.start();
    } catch (_) {
      // Never let audio failures interrupt gameplay.
    }
  }

  Future<void> toggleEnabled() async {
    enabledNotifier.value = !enabledNotifier.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabledNotifier.value);
    } catch (_) {}
  }
}
