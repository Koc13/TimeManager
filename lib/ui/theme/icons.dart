import 'package:flutter/widgets.dart';


/// The Phosphor icons the design uses (regular weight; a bold check).
///
/// Why not the `phosphor_flutter` package: its 2.1.0 (the latest) extends
/// `IconData`, which current Flutter has made `final`, so it no longer
/// compiles. The icon fonts are bundled from it instead (MIT, see
/// assets/fonts/Phosphor-LICENSE.txt) with the codepoints below.
abstract final class Ph {
  static const _regular = 'Phosphor';
  static const _bold = 'PhosphorBold';

  static const list = IconData(0xe2f0, fontFamily: _regular);
  static const caretLeft = IconData(0xe138, fontFamily: _regular);
  static const caretRight = IconData(0xe13a, fontFamily: _regular);
  static const caretUp = IconData(0xe13c, fontFamily: _regular);
  static const caretDown = IconData(0xe136, fontFamily: _regular);
  static const plus = IconData(0xe3d4, fontFamily: _regular);
  static const play = IconData(0xe3d0, fontFamily: _regular);
  static const timer = IconData(0xe492, fontFamily: _regular);
  static const calendarBlank = IconData(0xe10a, fontFamily: _regular);
  static const x = IconData(0xe4f6, fontFamily: _regular);
  static const warning = IconData(0xe4e0, fontFamily: _regular);
  static const folderOpen = IconData(0xe256, fontFamily: _regular);
  static const clock = IconData(0xe19a, fontFamily: _regular);
  static const dotsThreeVertical = IconData(0xe208, fontFamily: _regular);
  static const check = IconData(0xe182, fontFamily: _bold);
}
