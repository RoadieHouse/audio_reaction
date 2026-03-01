import 'dart:math';
import 'audio_cue.dart';

// ── Block Type Discriminator ──────────────────────────────────────────────────

/// Discriminator enum used for JSON serialisation / deserialisation.
enum SequenceBlockType {
  warmUp,
  delay,
  action;

  /// Safe lookup — throws [ArgumentError] for unknown values.
  static SequenceBlockType fromString(String value) {
    return SequenceBlockType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown SequenceBlockType: $value'),
    );
  }
}

// ── Abstract Base ─────────────────────────────────────────────────────────────

/// Base class for all blocks in a training sequence timeline.
///
/// Each block carries a unique [id] and declares its [type].
/// Concrete subclasses:
/// - [WarmUpBlock] — fixed-duration warm-up phase.
/// - [DelayBlock]  — a rest / gap between action blocks.
/// - [ActionBlock] — fires one of its [AudioCue]s (randomly if >1 provided).
abstract class SequenceBlock {
  const SequenceBlock({required this.id});

  final String id;

  SequenceBlockType get type;

  /// Serialises this block to a JSON map. The [type] key is always included
  /// so [SequenceBlock.fromJson] can reconstruct the correct subclass.
  Map<String, dynamic> toJson();

  /// Factory that deserialises any [SequenceBlock] subclass from [json].
  static SequenceBlock fromJson(Map<String, dynamic> json) {
    final blockType = SequenceBlockType.fromString(json['type'] as String);
    switch (blockType) {
      case SequenceBlockType.warmUp:
        return WarmUpBlock.fromJson(json);
      case SequenceBlockType.delay:
        return DelayBlock.fromJson(json);
      case SequenceBlockType.action:
        return ActionBlock.fromJson(json);
    }
  }
}

// ── WarmUpBlock ───────────────────────────────────────────────────────────────

/// A fixed-duration warm-up phase at the start of a session.
class WarmUpBlock extends SequenceBlock {
  const WarmUpBlock({
    required super.id,
    required this.duration,
  });

  /// Total duration of the warm-up period.
  final Duration duration;

  @override
  SequenceBlockType get type => SequenceBlockType.warmUp;

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory WarmUpBlock.fromJson(Map<String, dynamic> json) => WarmUpBlock(
        id: json['id'] as String,
        duration: Duration(seconds: json['durationSeconds'] as int),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'durationSeconds': duration.inSeconds,
      };

  // ── Utility ────────────────────────────────────────────────────────────────

  WarmUpBlock copyWith({String? id, Duration? duration}) => WarmUpBlock(
        id: id ?? this.id,
        duration: duration ?? this.duration,
      );

  @override
  String toString() =>
      'WarmUpBlock(id: $id, duration: ${duration.inSeconds}s)';
}

// ── DelayBlock ────────────────────────────────────────────────────────────────

/// A rest / gap block inserted between action blocks.
///
/// In a future implementation this could hold a [minDuration]/[maxDuration]
/// range for random delays; for now a single fixed [duration] is used.
class DelayBlock extends SequenceBlock {
  const DelayBlock({
    required super.id,
    required this.duration,
  });

  /// The rest duration.
  final Duration duration;

  @override
  SequenceBlockType get type => SequenceBlockType.delay;

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory DelayBlock.fromJson(Map<String, dynamic> json) => DelayBlock(
        id: json['id'] as String,
        duration: Duration(seconds: json['durationSeconds'] as int),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'durationSeconds': duration.inSeconds,
      };

  // ── Utility ────────────────────────────────────────────────────────────────

  DelayBlock copyWith({String? id, Duration? duration}) => DelayBlock(
        id: id ?? this.id,
        duration: duration ?? this.duration,
      );

  @override
  String toString() =>
      'DelayBlock(id: $id, duration: ${duration.inSeconds}s)';
}

// ── ActionBlock ───────────────────────────────────────────────────────────────

/// A block that fires an audio cue when the timer reaches it.
///
/// If [audioCues] contains a single entry, that cue is always played.
/// If it contains multiple entries, one is chosen at random each time the
/// block is triggered — enabling unpredictable reactive training.
class ActionBlock extends SequenceBlock {
  const ActionBlock({
    required super.id,
    required this.audioCues,
  }) : assert(audioCues.length > 0, 'ActionBlock must have at least one cue');

  /// The pool of cues to choose from. Must not be empty.
  final List<AudioCue> audioCues;

  @override
  SequenceBlockType get type => SequenceBlockType.action;

  /// Returns the cue to play for this trigger.
  ///
  /// - Single cue  → always returns that cue (deterministic).
  /// - Multiple cues → picks one uniformly at random (reactive/unpredictable).
  AudioCue pickCue([Random? rng]) {
    if (audioCues.length == 1) return audioCues.first;
    final random = rng ?? Random();
    return audioCues[random.nextInt(audioCues.length)];
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory ActionBlock.fromJson(Map<String, dynamic> json) => ActionBlock(
        id: json['id'] as String,
        audioCues: (json['audioCues'] as List<dynamic>)
            .map((e) => AudioCue.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'audioCues': audioCues.map((c) => c.toJson()).toList(),
      };

  // ── Utility ────────────────────────────────────────────────────────────────

  ActionBlock copyWith({String? id, List<AudioCue>? audioCues}) => ActionBlock(
        id: id ?? this.id,
        audioCues: audioCues ?? this.audioCues,
      );

  @override
  String toString() =>
      'ActionBlock(id: $id, cues: ${audioCues.map((c) => c.name).join(', ')})';
}
