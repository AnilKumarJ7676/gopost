import 'package:flutter/foundation.dart';

enum KeyframeProperty {
  positionX('Position X'),
  positionY('Position Y'),
  scale('Scale'),
  rotation('Rotation'),
  opacity('Opacity'),
  volume('Volume'),
  speed('Speed');

  final String label;
  const KeyframeProperty(this.label);

  double get defaultValue {
    switch (this) {
      case KeyframeProperty.scale:
      case KeyframeProperty.opacity:
      case KeyframeProperty.volume:
      case KeyframeProperty.speed:
        return 1.0;
      default:
        return 0.0;
    }
  }
}

enum KeyframeInterpolation {
  linear('Linear'),
  bezier('Bezier'),
  hold('Hold'),
  easeIn('Ease In'),
  easeOut('Ease Out'),
  easeInOut('Ease In Out');

  final String label;
  const KeyframeInterpolation(this.label);
}

@immutable
class Keyframe {
  final double time;
  final double value;
  final KeyframeInterpolation interpolation;

  const Keyframe({
    required this.time,
    required this.value,
    this.interpolation = KeyframeInterpolation.linear,
  });

  Keyframe copyWith({double? time, double? value, KeyframeInterpolation? interpolation}) {
    return Keyframe(
      time: time ?? this.time,
      value: value ?? this.value,
      interpolation: interpolation ?? this.interpolation,
    );
  }

  Map<String, dynamic> toMap() => {
    'time': time,
    'value': value,
    'interpolation': interpolation.index,
  };

  factory Keyframe.fromMap(Map<String, dynamic> m) => Keyframe(
    time: (m['time'] as num).toDouble(),
    value: (m['value'] as num).toDouble(),
    interpolation: KeyframeInterpolation.values[(m['interpolation'] as int?) ?? 0],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Keyframe && time == other.time && value == other.value;

  @override
  int get hashCode => Object.hash(time, value);
}

@immutable
class KeyframeTrack {
  final KeyframeProperty property;
  final List<Keyframe> keyframes;

  const KeyframeTrack({required this.property, this.keyframes = const []});

  double evaluate(double time) {
    if (keyframes.isEmpty) return property.defaultValue;
    if (keyframes.length == 1) return keyframes.first.value;

    if (time <= keyframes.first.time) return keyframes.first.value;
    if (time >= keyframes.last.time) return keyframes.last.value;

    for (int i = 0; i < keyframes.length - 1; i++) {
      final a = keyframes[i];
      final b = keyframes[i + 1];
      if (time >= a.time && time <= b.time) {
        if (a.interpolation == KeyframeInterpolation.hold) return a.value;
        final t = (time - a.time) / (b.time - a.time);
        final curved = _applyCurve(t, a.interpolation);
        return a.value + (b.value - a.value) * curved;
      }
    }
    return keyframes.last.value;
  }

  double _applyCurve(double t, KeyframeInterpolation interp) {
    switch (interp) {
      case KeyframeInterpolation.linear:
        return t;
      case KeyframeInterpolation.easeIn:
        return t * t;
      case KeyframeInterpolation.easeOut:
        return 1 - (1 - t) * (1 - t);
      case KeyframeInterpolation.easeInOut:
        return t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2;
      case KeyframeInterpolation.bezier:
        return t * t * (3 - 2 * t);
      case KeyframeInterpolation.hold:
        return 0;
    }
  }

  KeyframeTrack addKeyframe(Keyframe kf) {
    final updated = List<Keyframe>.from(keyframes);
    final idx = updated.indexWhere((k) => k.time == kf.time);
    if (idx >= 0) {
      updated[idx] = kf;
    } else {
      updated.add(kf);
      updated.sort((a, b) => a.time.compareTo(b.time));
    }
    return KeyframeTrack(property: property, keyframes: updated);
  }

  KeyframeTrack removeKeyframeAt(double time) {
    return KeyframeTrack(
      property: property,
      keyframes: keyframes.where((k) => k.time != time).toList(),
    );
  }

  KeyframeTrack moveKeyframe(double oldTime, double newTime, double newValue) {
    return KeyframeTrack(
      property: property,
      keyframes: keyframes.map((k) {
        if (k.time == oldTime) return k.copyWith(time: newTime, value: newValue);
        return k;
      }).toList()..sort((a, b) => a.time.compareTo(b.time)),
    );
  }
}

@immutable
class ClipKeyframes {
  final List<KeyframeTrack> tracks;

  const ClipKeyframes({this.tracks = const []});

  bool get isEmpty => tracks.isEmpty || tracks.every((t) => t.keyframes.isEmpty);

  KeyframeTrack? trackFor(KeyframeProperty property) {
    return tracks.where((t) => t.property == property).firstOrNull;
  }

  double evaluate(KeyframeProperty property, double time) {
    return trackFor(property)?.evaluate(time) ?? property.defaultValue;
  }

  ClipKeyframes updateTrack(KeyframeTrack track) {
    final updated = List<KeyframeTrack>.from(tracks);
    final idx = updated.indexWhere((t) => t.property == track.property);
    if (idx >= 0) {
      updated[idx] = track;
    } else {
      updated.add(track);
    }
    return ClipKeyframes(tracks: updated);
  }

  ClipKeyframes removeTrack(KeyframeProperty property) {
    return ClipKeyframes(
      tracks: tracks.where((t) => t.property != property).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'tracks': tracks.map((t) => {
      'property': t.property.index,
      'keyframes': t.keyframes.map((k) => k.toMap()).toList(),
    }).toList(),
  };

  factory ClipKeyframes.fromMap(Map<String, dynamic> m) {
    final raw = m['tracks'] as List<dynamic>? ?? [];
    return ClipKeyframes(
      tracks: raw.map((e) {
        final trackMap = e as Map<String, dynamic>;
        return KeyframeTrack(
          property: KeyframeProperty.values[trackMap['property'] as int],
          keyframes: (trackMap['keyframes'] as List<dynamic>)
              .map((k) => Keyframe.fromMap(k as Map<String, dynamic>))
              .toList(),
        );
      }).toList(),
    );
  }
}
