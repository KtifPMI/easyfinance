import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class FabAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const FabAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class ExpandableFab extends StatefulWidget {
  final List<FabAction> actions;
  const ExpandableFab({super.key, required this.actions});

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: Container(color: Colors.black26),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ...List.generate(widget.actions.length, (i) {
                final reversedIndex = widget.actions.length - 1 - i;
                final action = widget.actions[reversedIndex];
                return _buildActionButton(action, reversedIndex);
              }),
              const SizedBox(height: 12),
              _buildMainButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _isOpen ? AppColors.danger : AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _isOpen ? Icons.close : Icons.add,
            key: ValueKey(_isOpen),
            color: AppColors.onPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(FabAction action, int index) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final animationValue = _expandAnimation.value;
        return IgnorePointer(
          ignoring: animationValue < 0.1,
          child: Opacity(
          opacity: animationValue,
          child: Transform.translate(
            offset: Offset(0, -8 * (1 - animationValue)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isOpen ? 1.0 : 0.0,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(action.label, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _toggle();
                      action.onTap();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Icon(action.icon, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}
