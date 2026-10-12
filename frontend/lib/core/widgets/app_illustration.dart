import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Predefined multi-color illustrations for high-visibility UI moments.
class AppIllustrations {
  static const String deckReady = 'assets/illustrations/deck_ready.svg';
  static const String sessionReady = 'assets/illustrations/session_ready.svg';
  static const String achievementsEmpty =
      'assets/illustrations/achievements_empty.svg';
}

/// Unified AppIllustration widget for crisp multi-color vector scenes.
class AppIllustration extends StatelessWidget {
  final String assetPath;
  final double size;

  const AppIllustration(this.assetPath, {super.key, this.size = 80.0});

  const AppIllustration.deckReady({super.key, this.size = 80.0})
    : assetPath = AppIllustrations.deckReady;

  const AppIllustration.sessionReady({super.key, this.size = 80.0})
    : assetPath = AppIllustrations.sessionReady;

  const AppIllustration.achievementsEmpty({super.key, this.size = 80.0})
    : assetPath = AppIllustrations.achievementsEmpty;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(assetPath, width: size, height: size);
  }
}
