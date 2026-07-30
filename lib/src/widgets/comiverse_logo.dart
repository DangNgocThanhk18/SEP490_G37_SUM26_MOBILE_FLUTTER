import 'package:flutter/material.dart';

/// The exact React `components/common/LogoIcon.jsx` wordmark exported at 4x.
class ComiVerseLogo extends StatelessWidget {
  const ComiVerseLogo({super.key, this.height = 40});

  static const double aspectRatio = 6;
  static const String _darkAsset = 'assets/branding/comiverse_logo_dark.png';
  static const String _lightAsset = 'assets/branding/comiverse_logo_light.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).brightness == Brightness.dark
        ? _darkAsset
        : _lightAsset;
    return Semantics(
      image: true,
      label: 'ComiVerse',
      child: ExcludeSemantics(
        child: SizedBox(
          width: height * aspectRatio,
          height: height,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
