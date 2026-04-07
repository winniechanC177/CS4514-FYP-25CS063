import 'package:flutter/material.dart';

class LongPressFab extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback onLongPressCompleted;
  final String tooltip;
  final IconData icon;

  const LongPressFab({
    super.key,
    required this.onTap,
    required this.onLongPressCompleted,
    this.tooltip = '',
    this.icon = Icons.add,
  });

  @override
  State<LongPressFab> createState() => _LongPressFabState();
}

class _LongPressFabState extends State<LongPressFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;

  static const double _minWidth = 56.0;
  static const double _maxWidth = 160.0;
  static const Duration _holdDuration = Duration(milliseconds: 500);

  bool _draggedOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _holdDuration);
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _draggedOut = false;
    _controller.forward(from: 0.0);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggedOut) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final local = details.localPosition;
    if (local.dx < 0 || local.dy < 0 ||
        local.dx > size.width || local.dy > size.height) {
      _draggedOut = true;
      _controller.reverse();
    }
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (!_draggedOut && _controller.value >= 1.0) {
      widget.onLongPressCompleted();
    }
    _draggedOut = false;
    _controller.reverse();
  }

  void _onLongPressCancel() {
    _draggedOut = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = widget.onTap != null;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd: _onLongPressEnd,
        onLongPressCancel: _onLongPressCancel,
        child: AnimatedBuilder(
          animation: _expand,
          builder: (context, _) {
            final t = _expand.value;
            final width = _minWidth + (_maxWidth - _minWidth) * t;
            final radius = 16.0 + (28.0 - 16.0) * t;
            return Material(
              elevation: isEnabled ? 6.0 : 0.0,
              borderRadius: BorderRadius.circular(radius),
              color: isEnabled
                  ? scheme.primaryContainer
                  : scheme.onSurface.withValues(alpha: 0.12),
              child: SizedBox(
                width: width,
                height: _minWidth,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        color: isEnabled
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface.withValues(alpha: 0.38),
                      ),
                      if (t > 0.85) ...[
                        SizedBox(width: 8.0 * t),
                        Opacity(
                          opacity: ((t - 0.85) / 0.15).clamp(0.0, 1.0),
                          child: Text(
                            'New Session',
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 14.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

