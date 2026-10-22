import 'package:flutter/material.dart';

import '../services/music_service.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';

/// Side-by-side Sound (effects) and Music toggles, used on the menu and in
/// the pause overlay — each controls only its own channel.
class AudioToggles extends StatelessWidget {
  const AudioToggles({super.key});

  static const _style = TextStyle(color: AppPalette.menuTextAccent, fontSize: 16, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.enabledNotifier,
          builder: (context, enabled, _) => TextButton.icon(
            onPressed: SoundService.instance.toggleEnabled,
            icon: Icon(enabled ? Icons.volume_up : Icons.volume_off, color: AppPalette.menuTextAccent),
            label: Text(enabled ? 'Sound On' : 'Sound Off', style: _style),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<bool>(
          valueListenable: MusicService.instance.enabledNotifier,
          builder: (context, enabled, _) => TextButton.icon(
            onPressed: MusicService.instance.toggle,
            icon: Icon(enabled ? Icons.music_note : Icons.music_off, color: AppPalette.menuTextAccent),
            label: Text(enabled ? 'Music On' : 'Music Off', style: _style),
          ),
        ),
      ],
    );
  }
}
