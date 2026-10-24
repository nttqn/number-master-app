import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Reusable "LEVEL N" zoom-in / hold / zoom-out announcement, ~2s
/// choreography, matching the pattern used across this game series.
class LevelBannerOverlay extends StatefulWidget {
  const LevelBannerOverlay({super.key, required this.level, required this.onDone});

  final int level;
  final VoidCallback onDone;

  /// One-line heads-up on the level where each new obstacle first appears
  /// (see DifficultyParams.forLevel for where they phase in).
  static const Map<int, String> newObstacleHints = {
    3: 'NEW: Sliding saws — time your pass!',
    5: 'NEW: Gates that keep changing!',
    7: 'Saws now block the way around',
    8: 'NEW: Holes in the bridge — don\'t fall!',
  };

  @override
  State<LevelBannerOverlay> createState() => _LevelBannerOverlayState();
}

class _LevelBannerOverlayState extends State<LevelBannerOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // A bit longer when there's a hint to read.
    final hasHint = LevelBannerOverlay.newObstacleHints.containsKey(widget.level);
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: hasHint ? 2800 : 2000));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.overlayScrimLight,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LEVEL ${widget.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              if (LevelBannerOverlay.newObstacleHints[widget.level] case final hint?)
                Padding(
                  padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
