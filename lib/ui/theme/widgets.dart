/// Nocturne building blocks shared by every screen.
library;

import 'package:flutter/material.dart';

import 'nocturne.dart';
import 'icons.dart';

/// A 1px rule that fades to transparent over 48px at each end.
class FadedRule extends StatelessWidget {
  const FadedRule({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final fade = c.maxWidth > 96 ? 48 / c.maxWidth : 0.5;
      return Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: const [
              Colors.transparent,
              Noc.divider,
              Noc.divider,
              Colors.transparent,
            ],
            stops: [0, fade, 1 - fade, 1],
          ),
        ),
      );
    },
  );
}

/// A row with a faded rule under it (or above it, with [top]).
class Ruled extends StatelessWidget {
  const Ruled({super.key, required this.child, this.top = false});

  final Widget child;
  final bool top;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [if (top) const FadedRule(), child, if (!top) const FadedRule()],
  );
}

/// 10px uppercase label above a heading or list.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = Noc.accent300});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Noc.kicker.copyWith(color: color));
}

/// "Done 3", "Journal": 19/500 with an optional muted count.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count, this.trailing});

  final String text;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(text, style: Noc.sectionHead),
      if (count != null) ...[
        const SizedBox(width: 10),
        Text(count!, style: Noc.meta),
      ],
      const Spacer(),
      ?trailing,
    ],
  );
}

enum NocButtonKind { primary, secondary, ghost }

/// Outlined buttons only: primary (accent edge), secondary (divider edge,
/// text colour) and ghost (accent text, no edge).
class NocButton extends StatelessWidget {
  const NocButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = NocButtonKind.primary,
    this.icon,
    this.small = false,
    this.big = false,
    this.color,
  });

  const NocButton.secondary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.big = false,
  }) : kind = NocButtonKind.secondary,
       color = null;

  const NocButton.ghost(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.color,
  }) : kind = NocButtonKind.ghost,
       big = false;

  final String label;
  final VoidCallback? onPressed;
  final NocButtonKind kind;
  final IconData? icon;
  final bool small;
  final bool big;

  /// Overrides the text colour (e.g. a muted "Discard all").
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : big
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 16.6, vertical: 9.2);
    final fontSize = small
        ? 13.0
        : big
        ? 16.0
        : 14.0;
    final Color fg =
        color ??
        switch (kind) {
          NocButtonKind.primary || NocButtonKind.ghost => Noc.accent,
          NocButtonKind.secondary => Noc.text,
        };
    final style = ButtonStyle(
      padding: WidgetStatePropertyAll(
        kind == NocButtonKind.ghost
            ? EdgeInsets.symmetric(
                horizontal: 6,
                vertical: padding.vertical / 2,
              )
            : padding,
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, small ? 28 : 36)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.disabled) ? fg.withValues(alpha: 0.45) : fg,
      ),
      overlayColor: WidgetStatePropertyAll(
        (kind == NocButtonKind.secondary ? Noc.text : Noc.accent).withValues(
          alpha: 0.12,
        ),
      ),
      side: WidgetStateProperty.resolveWith((s) {
        if (kind == NocButtonKind.ghost) return BorderSide.none;
        final edge = kind == NocButtonKind.primary ? Noc.accent : Noc.divider;
        return BorderSide(
          color: s.contains(WidgetState.disabled)
              ? edge.withValues(alpha: 0.45)
              : edge,
        );
      }),
    );
    final text = Text(label);
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: text)
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: fontSize + 2),
            label: text,
          );
  }
}

/// 22×22 square checkbox: neutral edge when open, accent edge and check
/// when done.
class NocCheckbox extends StatelessWidget {
  const NocCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
    this.semanticLabel,
  });

  final bool checked;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    label: semanticLabel,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Noc.rSm),
      // A 22px box with a 44px touch target around it.
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Noc.rSm),
            border: Border.all(
              color: checked ? Noc.accent : Noc.neutral600,
              width: 1.5,
            ),
          ),
          child: checked
              ? const Icon(Ph.check, size: 14, color: Noc.accent)
              : null,
        ),
      ),
    ),
  );
}

/// Small priority tag: "High" (accent) or "Low" (neutral).
class NocTag extends StatelessWidget {
  const NocTag(this.text, {super.key, this.accent = true});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: accent ? Noc.accent800 : Noc.neutral800,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: accent ? const Color(0xFFF5F4FF) : Noc.neutral100,
      ),
    ),
  );
}

/// Segmented control: divider frame, separators, the selected segment in
/// accent text with an inset accent ring.
class NocSegmented<T> extends StatelessWidget {
  const NocSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.minWidth = 64,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double minWidth;

  // Scales down rather than overflowing with large system font sizes.
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: _frame(),
  );

  Widget _frame() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Noc.divider),
      borderRadius: BorderRadius.circular(Noc.rMd),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (value, label)) in options.indexed) ...[
            if (i > 0) const VerticalDivider(width: 1, color: Noc.divider),
            Semantics(
              selected: value == selected,
              button: true,
              child: InkWell(
                onTap: () => onChanged(value),
                child: Container(
                  constraints: BoxConstraints(minWidth: minWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  alignment: Alignment.center,
                  decoration: value == selected
                      ? BoxDecoration(
                          border: Border.all(color: Noc.accent),
                          borderRadius: BorderRadius.circular(
                            i == 0 || i == options.length - 1 ? Noc.rMd - 1 : 0,
                          ),
                        )
                      : null,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: value == selected ? Noc.accent300 : Noc.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 40×22 outlined pill switch with a sliding 13px knob.
class NocSwitch extends StatelessWidget {
  const NocSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? Noc.accent : Noc.neutral600;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Container(
            width: 40,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color, width: 1.5),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin progress bar: 2px on a divider track (ToDo header) or 6px with
/// rounded ends on a neutral track (goals). Fill clamps at 100%.
class NocProgress extends StatelessWidget {
  const NocProgress({super.key, required this.value, this.thick = false});

  final double value;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    final h = thick ? 6.0 : 2.0;
    final radius = BorderRadius.circular(thick ? 3 : 0);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: h,
        color: thick ? Noc.neutral800 : Noc.divider,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: Duration(milliseconds: thick ? 500 : 400),
          curve: Curves.easeOut,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                color: Noc.accent,
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Surface-filled card, radius 8, no border or shadow.
class NocCard extends StatelessWidget {
  const NocCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Noc.surface,
      borderRadius: BorderRadius.circular(Noc.rMd),
    ),
    child: child,
  );
}

/// One square of a heat map: intensity [level] 0–4, an optional number
/// [label] or a [check]. Reusable beyond habits (e.g. a goal heat map).
class HeatCell extends StatelessWidget {
  const HeatCell({
    super.key,
    required this.level,
    this.label,
    this.check = false,
    this.isToday = false,
    this.enabled = true,
    this.onTap,
    this.size = 36,
    this.semanticLabel,
  });

  final int level;
  final String? label;
  final bool check;
  final bool isToday;
  final bool enabled;
  final VoidCallback? onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = level >= 3 ? Noc.neutral100 : Noc.accent300;
    final border = isToday
        ? Noc.accent400
        : level == 0
        ? Noc.neutral800
        : Colors.transparent;
    return Semantics(
      label: semanticLabel,
      button: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(Noc.rSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Noc.heat[level.clamp(0, 4)],
              borderRadius: BorderRadius.circular(Noc.rSm),
              border: Border.all(color: border),
            ),
            child: check
                ? const Icon(Ph.check, size: 17, color: Noc.neutral100)
                : label == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(2),
                    child: FittedBox(
                      child: Text(
                        label!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Heat level for a value against a per-day target:
/// 0 for nothing, else `ceil(value / target × 4)` clamped to 1–4.
int levelFor(num value, num target) {
  if (value <= 0) return 0;
  if (target <= 0) return 4;
  return (value / target * 4).ceil().clamp(1, 4);
}
