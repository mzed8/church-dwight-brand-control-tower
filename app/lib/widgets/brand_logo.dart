import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/brand_theme.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final bool showSubtitle;

  const BrandLogo({super.key, this.height = 32, this.showSubtitle = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand-logo.png',
          height: height,
          width: height,
          fit: BoxFit.contain,
        ),
        SizedBox(width: height * 0.3),
        if (showSubtitle)
          Text(
            'BRAND CONTROL TOWER',
            style: GoogleFonts.inter(
              fontSize: height * 0.35,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? BrandColors.textDark
                  : BrandColors.textPrimary,
              letterSpacing: 3,
            ),
          ),
      ],
    );
  }
}
