import 'package:flutter/material.dart';

class MicIndicator extends StatefulWidget {
  final bool isActive;
  final String label;

  const MicIndicator({
    super.key,
    required this.isActive,
    this.label = 'Listening...',
  });

  @override
  State<MicIndicator> createState() => _MicIndicatorState();
}

class _MicIndicatorState extends State<MicIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MicIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isActive ? _animation.value : 1.0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.isActive ? Colors.redAccent : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          widget.isActive ? widget.label : 'Inactive',
          style: TextStyle(
            color: widget.isActive ? Colors.redAccent : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
