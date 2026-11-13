import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The exact supplied wordmark, cropped to its visible lockup.
///
/// `birimm_logo.png` is a square canvas with generous transparent padding. A
/// `BoxFit.cover` frame around the lockup ratio removes that padding visually
/// without editing or re-exporting the source image.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width = 156,
    this.height,
    this.onDarkPlate = true,
  });

  final double width;
  final double? height;
  final bool onDarkPlate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolvedHeight = height ?? width * 0.3;
    final logo = ClipRect(
      child: Image.asset(
        'birimm_logo.png',
        width: width,
        height: resolvedHeight,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Birimm',
      ),
    );

    if (!onDarkPlate) return logo;

    return Container(
      width: width + 24,
      height: resolvedHeight + 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF14130F),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? colors.border
              : const Color(0xFF27251E),
        ),
      ),
      child: logo,
    );
  }
}

/// A compact monogram tile used where a full wordmark would be too wide.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF14130F),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? colors.border
              : const Color(0xFF27251E),
        ),
      ),
      child: Text(
        'b',
        style: TextStyle(
          color: colors.accent,
          fontSize: size * 0.54,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

/// Compatibility alias for the startup surface.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    return BrandLogo(width: width);
  }
}
