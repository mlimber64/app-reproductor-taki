import 'dart:async';

import '../domain/ports/search_scheduler.dart';

/// [SearchScheduler] real, sobre `Timer`.
class TimerSearchScheduler implements SearchScheduler {
  const TimerSearchScheduler();

  @override
  CancelScheduled schedule(Duration delay, void Function() action) {
    final timer = Timer(delay, action);
    return timer.cancel;
  }
}
