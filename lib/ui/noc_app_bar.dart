import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/timer_state.dart';
import '../providers/data_providers.dart';
import '../providers/timer_controller.dart';
import 'navigation.dart';
import 'theme/nocturne.dart';
import 'theme/widgets.dart';
import 'theme/icons.dart';

/// The shared app bar: menu, then a centred [center] widget (the ToDo's
/// Day/Week/Month control) or a left-aligned [title], then the running
/// timer chip (or an equal spacer so the centre stays centred).
class NocAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NocAppBar({
    super.key,
    required this.scaffoldKey,
    this.title,
    this.center,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final String? title;
  final Widget? center;

  @override
  Size get preferredSize => const Size.fromHeight(57);

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Open navigation menu',
                  icon: const Icon(Ph.list, size: 22),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 6),
                if (center != null)
                  Expanded(child: Center(child: center))
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(title ?? '', style: Noc.title),
                    ),
                  ),
                const SizedBox(width: 6),
                const TimerChip(),
              ],
            ),
          ),
        ),
        const FadedRule(),
      ],
    ),
  );
}

/// mm:ss of the running work block or break, outside the Timer section;
/// tapping it opens the Timer. Otherwise a 36px spacer.
class TimerChip extends ConsumerStatefulWidget {
  const TimerChip({super.key});

  @override
  ConsumerState<TimerChip> createState() => _TimerChipState();
}

class _TimerChipState extends ConsumerState<TimerChip> {
  Timer? _repaint;

  @override
  void dispose() {
    _repaint?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final show =
        timer != null &&
        timer.phase != TimerPhase.breakOffer &&
        ref.watch(sectionProvider) != Section.timer;
    if (!show) {
      _repaint?.cancel();
      _repaint = null;
      return const SizedBox(width: 36);
    }
    _repaint ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    final left = timer.remaining(ref.read(clockProvider)());
    return OutlinedButton.icon(
      onPressed: () => ref.read(sectionProvider.notifier).go(Section.timer),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        minimumSize: const Size(0, 28),
        foregroundColor: Noc.accent300,
        side: const BorderSide(color: Noc.accent),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      icon: const Icon(Ph.timer, size: 14),
      label: Text(countdown(left)),
    );
  }
}

/// "24:59". Minutes aren't wrapped into hours: blocks are at most 90 min.
String countdown(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
