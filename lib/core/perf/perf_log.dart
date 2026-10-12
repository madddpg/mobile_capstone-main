import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Times one test cycle per named session, for the Mobile Performance Test
/// Document.
///
/// [begin] at the user's tap, [response] when the backend result arrives,
/// [screenShown] in the next screen's initState, and [contentReady] when
/// its real content is on screen. Each metric prints one logcat line,
/// `PERF <name> <metric> <ms> ms`, at most once per session, in release
/// builds too. A session that was never begun, or has ended, ignores every
/// call, so screens reached another way print nothing.
class PerfLog {
  PerfLog._();

  static final Map<String, _PerfSession> _sessions = {};

  /// Where lines go. Tests swap it to capture output.
  @visibleForTesting
  static void Function(String line) printer = _logcat;

  static void _logcat(String line) => debugPrint(line);

  /// Starts (or restarts) the session [name] at the user's tap.
  static void begin(String name) {
    _sessions[name] = _PerfSession()..stopwatch.start();
  }

  /// The backend call for [name] returned.
  static void response(String name) {
    final session = _active(name);
    if (session == null || session.responseAt != null) return;
    session.responseAt = session.elapsed;
    _print(name, 'response', session.responseAt!);
  }

  /// The next screen for [name] is being built. Prints `load` once that
  /// screen's first frame has been drawn.
  static void screenShown(String name) {
    final session = _active(name);
    if (session == null || session.shownAt != null) return;
    session.shownAt = session.elapsed;
    _afterNextFrame(() => _print(name, 'load', session.elapsed));
  }

  /// The real content for [name] is on screen. Prints `render` once the
  /// next frame has been drawn, then ends the session.
  static void contentReady(String name) {
    final session = _active(name);
    if (session == null || session.renderRequested) return;
    session.renderRequested = true;
    final from = session.shownAt ?? session.responseAt ?? 0;
    _afterNextFrame(() {
      _print(name, 'render', session.elapsed - from);
      session.stopwatch.stop();
      if (identical(_sessions[name], session)) _sessions.remove(name);
    });
  }

  static _PerfSession? _active(String name) {
    final session = _sessions[name];
    if (session == null || session.renderRequested) return null;
    return session;
  }

  static void _afterNextFrame(VoidCallback callback) {
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) => callback());
    binding.ensureVisualUpdate();
  }

  static void _print(String name, String metric, int ms) {
    printer('PERF $name $metric $ms ms');
  }

  /// Forgets every session. For tests.
  @visibleForTesting
  static void reset() => _sessions.clear();
}

class _PerfSession {
  final Stopwatch stopwatch = Stopwatch();
  int? responseAt;
  int? shownAt;
  bool renderRequested = false;

  int get elapsed => stopwatch.elapsedMilliseconds;
}
