import 'package:flutter/foundation.dart';

enum TransitionType {
  none('None'),
  fade('Fade'),
  dissolve('Dissolve'),
  slideLeft('Slide Left'),
  slideRight('Slide Right'),
  slideUp('Slide Up'),
  slideDown('Slide Down'),
  wipeLeft('Wipe Left'),
  wipeRight('Wipe Right'),
  wipeUp('Wipe Up'),
  wipeDown('Wipe Down'),
  zoom('Zoom'),
  push('Push'),
  reveal('Reveal'),
  iris('Iris'),
  clock('Clock Wipe'),
  blur('Blur'),
  glitch('Glitch'),
  morph('Morph'),
  flash('Flash'),
  spin('Spin');

  final String label;
  const TransitionType(this.label);
}

enum EasingCurve {
  linear('Linear'),
  easeIn('Ease In'),
  easeOut('Ease Out'),
  easeInOut('Ease In Out'),
  cubicBezier('Cubic Bezier');

  final String label;
  const EasingCurve(this.label);
}

@immutable
class ClipTransition {
  final TransitionType type;
  final double durationSeconds;
  final EasingCurve easing;

  const ClipTransition({
    this.type = TransitionType.none,
    this.durationSeconds = 0.5,
    this.easing = EasingCurve.easeInOut,
  });

  bool get isNone => type == TransitionType.none;

  ClipTransition copyWith({
    TransitionType? type,
    double? durationSeconds,
    EasingCurve? easing,
  }) {
    return ClipTransition(
      type: type ?? this.type,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      easing: easing ?? this.easing,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.index,
    'durationSeconds': durationSeconds,
    'easing': easing.index,
  };

  factory ClipTransition.fromMap(Map<String, dynamic> m) => ClipTransition(
    type: TransitionType.values[(m['type'] as int?) ?? 0],
    durationSeconds: (m['durationSeconds'] as num?)?.toDouble() ?? 0.5,
    easing: EasingCurve.values[(m['easing'] as int?) ?? 3],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipTransition && type == other.type &&
      durationSeconds == other.durationSeconds && easing == other.easing;

  @override
  int get hashCode => Object.hash(type, durationSeconds, easing);
}
