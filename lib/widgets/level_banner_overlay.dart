import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Reusable "LEVEL N" zoom-in / hold / zoom-out announcement, ~2s
/// choreography, matching the pattern used across this game series.
class LevelBannerOverlay extends StatefulWidget {
  const LevelBannerOverlay({super.key, required this.level, required this.onDone});

  final int level;
  final VoidCallback onDone;

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
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
          child: Text(
            'LEVEL ${widget.level}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
