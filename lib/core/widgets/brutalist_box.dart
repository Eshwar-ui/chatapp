import 'package:flutter/material.dart';
import '../design/brutalist_colors.dart';
import '../design/brutalist_theme.dart';

/// Shared rounded surface used across the app.
class BrutalistBox extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final bool useOffsetShadow;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const BrutalistBox({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.useOffsetShadow = true,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? BrutalistColors.lightSurface;
    final border = borderColor ?? BrutalistColors.lightBorder;
    final width = borderWidth ?? BrutalistTheme.borderWidth;
    final radius = borderRadius ?? BrutalistTheme.radiusMD;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: width),
        boxShadow: useOffsetShadow ? BrutalistTheme.getOffsetShadow() : null,
      ),
      child: child,
    );
  }
}

/// Shared full-width action button with a tactile press response.
///
/// Motion is motivated: the scale-down on press gives physical "push"
/// feedback acknowledging the tap (MOTION_INTENSITY 4).
class BrutalistButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final bool isPrimary;
  final IconData? icon;

  const BrutalistButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.isPrimary = true,
    this.icon,
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bgColor =
        widget.backgroundColor ??
        (widget.isPrimary
            ? BrutalistColors.primaryAccent
            : Colors.transparent);
    final txtColor =
        widget.textColor ??
        (widget.isPrimary
            ? BrutalistColors.pureWhite
            : BrutalistColors.lightText);
    final border = widget.borderColor ?? BrutalistColors.lightBorder;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: BrutalistTheme.spacingXL,
              vertical: BrutalistTheme.spacingMD + 2,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
              border: Border.all(
                color: widget.isPrimary ? bgColor : border,
                width: BrutalistTheme.borderWidth,
              ),
              boxShadow: widget.isPrimary
                  ? [
                      BoxShadow(
                        color: bgColor.withValues(alpha: 0.28),
                        offset: const Offset(0, 6),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: txtColor, size: 20),
                  const SizedBox(width: BrutalistTheme.spacingSM),
                ],
                Text(
                  widget.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: txtColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
