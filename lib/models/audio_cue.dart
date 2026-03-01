/// Represents a single audio cue that can be triggered during a training
/// session. Cues are either bundled default assets or user-recorded clips.
class AudioCue {
  const AudioCue({
    required this.id,
    required this.name,
    this.filePath,
    required this.isCustom,
  });

  /// Unique identifier (e.g., UUID or timestamp-based string).
  final String id;

  /// Human-readable label shown in the UI (e.g., 'Beep High', 'Left', 'Right').
  final String name;

  /// For default assets: the Flutter asset path (e.g., 'assets/sounds/beep_high.mp3').
  /// For custom recordings: the absolute device filesystem path.
  /// Null only if the audio engine resolves the sound by [id] at runtime.
  final String? filePath;

  /// True when this cue was recorded by the user; false for bundled defaults.
  final bool isCustom;

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory AudioCue.fromJson(Map<String, dynamic> json) => AudioCue(
        id: json['id'] as String,
        name: json['name'] as String,
        filePath: json['filePath'] as String?,
        isCustom: json['isCustom'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'isCustom': isCustom,
      };

  // ── Utility ────────────────────────────────────────────────────────────────

  AudioCue copyWith({
    String? id,
    String? name,
    String? filePath,
    bool? isCustom,
  }) =>
      AudioCue(
        id: id ?? this.id,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        isCustom: isCustom ?? this.isCustom,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AudioCue && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AudioCue(id: $id, name: $name, isCustom: $isCustom)';
}
