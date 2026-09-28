import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_motion.dart';

/// Wraps any tappable surface with the DS press response: scale to 0.98 over
/// 100ms with the easeOut curve. Use for cards, tiles, chips, FABs.
class SeaLankaPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const SeaLankaPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<SeaLankaPressable> createState() => _SeaLankaPressableState();
}

class _SeaLankaPressableState extends State<SeaLankaPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? AppMotion.tapScale : 1.0,
        duration: AppMotion.tap,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}
