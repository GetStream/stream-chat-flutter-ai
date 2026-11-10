import 'dart:async';

/// Timers that run only when [elapse] moves their clock past them.
final class FakeTimers {
  Duration _now = Duration.zero;
  final _timers = <_FakeTimer>[];

  /// Starts a timer, as `OpenUITimerFactory` does.
  Timer call(Duration duration, void Function() callback) {
    final timer = _FakeTimer(_now + duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// The timers still waiting.
  int get pending => _timers.where((timer) => timer.isActive).length;

  /// Moves the clock by `duration`, running each timer due, in order, and
  /// the microtasks after each.
  Future<void> elapse(Duration duration) async {
    final end = _now + duration;
    while (true) {
      final due = _timers.where((timer) => timer.isActive && timer.due <= end).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final timer = due.first;
      _now = timer.due;
      timer.fire();
      await pumpMicrotasks();
    }
    _now = end;
    await pumpMicrotasks();
  }
}

/// Lets pending futures complete.
Future<void> pumpMicrotasks() async {
  for (var i = 0; i < 5; i += 1) {
    await Future<void>.value();
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._callback);

  final Duration due;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
