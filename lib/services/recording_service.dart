import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Handles microphone permission and audio recording lifecycle.
///
/// Recordings are saved as .m4a files inside the app's private documents
/// directory under a `recordings/` sub-folder. The returned file path from
/// [stopRecording] is what gets stored in [AudioCue.filePath] for custom cues.
class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  // ── Permission ──────────────────────────────────────────────────────────────

  /// Requests microphone access and returns whether it was granted.
  ///
  /// On iOS this triggers the system permission dialog on first call;
  /// subsequent calls return the cached status without a dialog.
  /// On Android (API 23+) the same system dialog is shown as needed.
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      _log('requestPermission() failed: $e');
      return false;
    }
  }

  // ── Recording ───────────────────────────────────────────────────────────────

  /// Begins recording to `<app-documents>/recordings/<fileName>.m4a`.
  ///
  /// If a recording is already in progress it is stopped first so callers
  /// don't need to manage that state themselves.
  ///
  /// Throws if microphone permission has not been granted — call
  /// [requestPermission] before invoking this method.
  Future<void> startRecording(String fileName) async {
    try {
      // Guard: stop any in-progress recording before starting a new one.
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      final path = await _buildRecordingPath(fileName);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // .m4a — widely supported on iOS & Android
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
    } catch (e) {
      _log('startRecording("$fileName") failed: $e');
      rethrow;
    }
  }

  /// Stops the active recording and returns the absolute path of the saved file.
  ///
  /// Returns `null` if no recording was in progress or if an error occurred.
  /// The caller should treat a `null` return as a failed recording.
  Future<String?> stopRecording() async {
    try {
      if (!await _recorder.isRecording()) return null;
      return await _recorder.stop(); // returns the file path
    } catch (e) {
      _log('stopRecording() failed: $e');
      return null;
    }
  }

  // ── Disposal ────────────────────────────────────────────────────────────────

  /// Release the underlying recorder resources.
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (e) {
      _log('dispose() failed: $e');
    }
  }

  // ── Private Helpers ─────────────────────────────────────────────────────────

  /// Builds the full file path for a new recording, creating the `recordings/`
  /// sub-directory if it doesn't already exist.
  Future<String> _buildRecordingPath(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/recordings');

    if (!recordingsDir.existsSync()) {
      await recordingsDir.create(recursive: true);
    }

    // Sanitise the file name and ensure the .m4a extension is present.
    final sanitised = fileName.replaceAll(RegExp(r'[^\w\-]'), '_');
    final name = sanitised.endsWith('.m4a') ? sanitised : '$sanitised.m4a';

    return '${recordingsDir.path}/$name';
  }

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[RecordingService] $message');
      return true;
    }());
  }
}
