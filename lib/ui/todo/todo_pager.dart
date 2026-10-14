import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import 'task_editor.dart';
import 'period_page.dart';

/// Daily, Weekly and Monthly ToDo side by side in a horizontal PageView.
///
/// The visible period of each page lives here, not in a provider: only this
/// screen and its add button need it, and it resets to "now" whenever the
/// day changes.
class TodoPager extends ConsumerStatefulWidget {
  const TodoPager({super.key, required this.scaffoldKey, required this.drawer});

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  @override
  ConsumerState<TodoPager> createState() => _TodoPagerState();
}

class _TodoPagerState extends ConsumerState<TodoPager> {
  final _pages = PageController();
  int _page = 0;
  late List<Period> _periods = _current(ref.read(todayProvider));

  static List<Period> _current(DateTime today) => [
    for (final kind in PeriodKind.values) Period.of(kind, today),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Period get _period => _periods[_page];

  void _show(Period period) => setState(() => _periods[_page] = period);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _show(Period.of(_period.kind, picked));
  }

  Future<void> _add() async {
    final period = _period;
    final result = await showTaskEditor(context);
    if (result == null || !mounted) return;
    final data = ref.read(appDataProvider.notifier);
    final repeat = result.repeat;
    final reminder = result.reminder;
    await runAction(
      context,
      () => repeat == null
          ? data.addTask(
              period,
              title: result.title,
              priority: result.priority,
              deadline: result.deadline,
              reminder: reminder,
            )
          : data.createRecurring(
              title: result.title,
              priority: result.priority,
              rule: repeat,
              reminderMinute: reminder == null
                  ? null
                  : reminder.hour * 60 + reminder.minute,
            ),
    );
  }

  // Swiping right on the first page has nowhere to go, so it opens the
  // drawer. Overscroll is used instead of a competing drag recognizer, which
  // would fight the PageView in the gesture arena. depth == 0 ignores
  // overscroll bubbling up from the vertical lists inside each page.
  bool _onOverscroll(OverscrollNotification n) {
    if (n.depth == 0 &&
        _page == 0 &&
        n.overscroll < 0 &&
        n.dragDetails != null) {
      widget.scaffoldKey.currentState?.openDrawer();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(todayProvider, (_, today) {
      setState(() => _periods = _current(today));
    });
    final isCurrent =
        _period == Period.of(_period.kind, ref.watch(todayProvider));

    return Scaffold(
      key: widget.scaffoldKey,
      drawer: widget.drawer,
      appBar: AppBar(
        title: GestureDetector(
          // Tapping the title jumps back to the current period.
          onTap: () => _show(Period.of(_period.kind, ref.read(todayProvider))),
          child: Text(
            periodLabel(_period),
            style: isCurrent
                ? null
                : TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Previous',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _show(_period.previous),
          ),
          IconButton(
            tooltip: 'Next',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _show(_period.next),
          ),
          IconButton(
            tooltip: 'Go to date',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDate,
          ),
        ],
        bottom: _PageDots(page: _page),
      ),
      body: NotificationListener<OverscrollNotification>(
        onNotification: _onOverscroll,
        child: PageView(
          controller: _pages,
          // Clamping (not bouncing) physics is what emits overscroll
          // notifications at the first page on every platform.
          physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
          onPageChanged: (page) => setState(() => _page = page),
          children: [for (final period in _periods) PeriodPage(period: period)],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// "Day · Week · Month" with the current page highlighted.
class _PageDots extends StatelessWidget implements PreferredSizeWidget {
  const _PageDots({required this.page});

  final int page;

  @override
  Size get preferredSize => const Size.fromHeight(24);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const labels = ['Day', 'Week', 'Month'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == page ? FontWeight.w600 : null,
                  color: i == page ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
