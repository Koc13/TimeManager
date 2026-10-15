import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/timer_controller.dart';

enum Section { todo, timer, goals, habits, settings }

/// The visible section. A provider (not shell state) because the timer chip
/// in every section's app bar switches to the Timer.
final sectionProvider = NotifierProvider<SectionController, Section>(
  SectionController.new,
);

class SectionController extends Notifier<Section> {
  // A cold start opens the Daily ToDo, or the Timer while a work block or
  // break is running or waiting at its break offer. Coming back from the
  // background keeps whatever section was open (this state survives).
  @override
  Section build() =>
      ref.read(timerProvider) == null ? Section.todo : Section.timer;

  void go(Section section) => state = section;
}
