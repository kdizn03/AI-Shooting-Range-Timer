import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Status dot with label. When [isActive], the dot pulses gently unless the
/// platform requests reduced motion. The label always states the status,
/// so meaning never depends on colour or animation.
class MicIndicator extends StatefulWidget {
  final bool isActive;
  final String label;

  /// Dot/label colour while active.
  final Color color;

  /// Label shown when inactive.
  final String inactiveLabel;

  const MicIndicator({
    super.key,
    required this.isActive,
    this.label = 'Listening',
    this.color = AppColors.accent,
    this.inactiveLabel = 'Inactive',
  });

  @override
  State<MicIndicator> createState() => _MicIndicatorState();
}

class _MicIndicatorState extends State<MicIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _sync() {
    if (widget.isActive && !_reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true, min: 0.35, max: 1);
      }
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MicIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color c = widget.isActive ? widget.color : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: FadeTransition(
            opacity: _controller,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Flexible(
          child: Text(
            widget.isActive ? widget.label : widget.inactiveLabel,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
