import '../models/audio_cue.dart';

/// Static registry of every bundled default sound.
///
/// Each [AudioCue] maps to a real file under `assets/sounds/`.
/// IDs are stable lowercase strings — safe to persist in saved sessions.
const List<AudioCue> kDefaultAudioCues = [
  AudioCue(
    id: 'blub_beep',
    name: 'Blub Beep',
    filePath: 'assets/sounds/blub_beep.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'censor_beep',
    name: 'Censor Beep',
    filePath: 'assets/sounds/censor_beep.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'countdown',
    name: 'Countdown',
    filePath: 'assets/sounds/countdown.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'hint',
    name: 'Hint',
    filePath: 'assets/sounds/hint.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'hollow_bell',
    name: 'Hollow Bell',
    filePath: 'assets/sounds/hollow_bell.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'level_up',
    name: 'Level Up',
    filePath: 'assets/sounds/level_up.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'long_beep',
    name: 'Long Beep',
    filePath: 'assets/sounds/long_beep.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'low_bell',
    name: 'Low Bell',
    filePath: 'assets/sounds/low_bell.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'machine_beep',
    name: 'Machine Beep',
    filePath: 'assets/sounds/machine_beep.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'pop',
    name: 'Pop',
    filePath: 'assets/sounds/pop.wav',
    isCustom: false,
  ),
  AudioCue(
    id: 'short_beep',
    name: 'Short Beep',
    filePath: 'assets/sounds/short_beep.wav',
    isCustom: false,
  ),
];
