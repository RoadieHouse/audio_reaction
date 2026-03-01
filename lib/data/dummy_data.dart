/// Dummy data models and static fixtures for the Sprint React UI prototype.
/// No business logic — purely for populating screens during visual development.

// ── Session Model ─────────────────────────────────────────────────────────────

class DummySession {
  const DummySession({
    required this.id,
    required this.name,
    required this.duration,
    required this.blockCount,
  });

  final String id;
  final String name;
  final String duration;  // e.g., "4 min 30 sec"
  final int blockCount;
}

// ── Session Block Model ───────────────────────────────────────────────────────

enum BlockType { warmUp, loopStart, action, delay }

class DummyBlock {
  const DummyBlock({
    required this.id,
    required this.type,
    required this.label,
    required this.subtitle,
  });

  final String id;
  final BlockType type;
  final String label;
  final String subtitle;
}

// ── Sound Model ───────────────────────────────────────────────────────────────

class DummySound {
  const DummySound({required this.id, required this.name, required this.duration});

  final String id;
  final String name;
  final String duration; // e.g., "0.4s"
}

// ── Static Fixtures ───────────────────────────────────────────────────────────

const List<DummySession> kDummySessions = [
  DummySession(id: '1', name: '5-3-2 Ladder Drill', duration: '4 min 30 sec', blockCount: 6),
  DummySession(id: '2', name: 'Direction Chaos', duration: '6 min 00 sec', blockCount: 9),
  DummySession(id: '3', name: 'Quick React Warm-Up', duration: '2 min 15 sec', blockCount: 4),
  DummySession(id: '4', name: 'Full Sprint Protocol', duration: '10 min 00 sec', blockCount: 14),
];

const List<DummyBlock> kDummyBlocks = [
  DummyBlock(id: 'b1', type: BlockType.warmUp,   label: 'Warm-Up',    subtitle: '60 sec · Light Jog'),
  DummyBlock(id: 'b2', type: BlockType.loopStart, label: 'Loop ×5',   subtitle: 'Repeat the following 5 times'),
  DummyBlock(id: 'b3', type: BlockType.action,    label: 'Left Cue',  subtitle: 'Sprint Left · Beep High'),
  DummyBlock(id: 'b4', type: BlockType.delay,     label: 'Rest',      subtitle: '2 – 4 sec random delay'),
  DummyBlock(id: 'b5', type: BlockType.action,    label: 'Right Cue', subtitle: 'Sprint Right · Beep Low'),
  DummyBlock(id: 'b6', type: BlockType.delay,     label: 'Rest',      subtitle: '3 sec fixed delay'),
];

const List<DummySound> kDefaultSounds = [
  DummySound(id: 's1', name: 'Beep High',    duration: '0.3s'),
  DummySound(id: 's2', name: 'Beep Low',     duration: '0.3s'),
  DummySound(id: 's3', name: 'Double Beep',  duration: '0.6s'),
  DummySound(id: 's4', name: 'Whistle',      duration: '0.8s'),
  DummySound(id: 's5', name: 'Air Horn',     duration: '1.0s'),
];

const List<DummySound> kMyRecordings = [
  DummySound(id: 'r1', name: 'Voice: Left',   duration: '0.5s'),
  DummySound(id: 'r2', name: 'Voice: Right',  duration: '0.5s'),
  DummySound(id: 'r3', name: 'Voice: Go!',    duration: '0.4s'),
  DummySound(id: 'r4', name: 'Voice: Sprint', duration: '0.6s'),
];
