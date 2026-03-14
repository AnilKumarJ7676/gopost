import 'package:flutter/material.dart';

/// Wraps any child widget with a static neon glow border when [isActive] is true.
/// Uses a lightweight static glow instead of continuous animation to avoid
/// 60fps AnimationController overhead across many widgets.
class NeonGlow extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final Color baseColor;
  final double borderRadius;
  final double glowSpread;
  final double glowBlur;
  final Duration cycleDuration;

  const NeonGlow({
    super.key,
    required this.child,
    required this.isActive,
    this.baseColor = const Color(0xFF6C63FF),
    this.borderRadius = 8,
    this.glowSpread = 2,
    this.glowBlur = 12,
    this.cycleDuration = const Duration(milliseconds: 2400),
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            blurRadius: glowBlur * 0.8,
            spreadRadius: glowSpread * 0.8,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.15),
            blurRadius: glowBlur * 1.4,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Variant specifically for icon buttons in sidebars / toolbars.
class NeonGlowIcon extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final Color baseColor;

  const NeonGlowIcon({
    super.key,
    required this.child,
    required this.isActive,
    this.baseColor = const Color(0xFF6C63FF),
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A FilterChip-style button with neon glow when selected.
class NeonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Color activeColor;

  const NeonChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.activeColor = const Color(0xFF6C63FF),
  });

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return FilterChip(
        label: Text(label),
        selected: false,
        onSelected: onSelected,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: FilterChip(
        label: Text(label),
        selected: true,
        onSelected: onSelected,
        selectedColor: activeColor.withValues(alpha: 0.25),
        checkmarkColor: activeColor,
        side: BorderSide(color: activeColor.withValues(alpha: 0.6)),
      ),
    );
  }
}
