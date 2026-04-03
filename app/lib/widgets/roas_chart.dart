import 'package:flutter/material.dart';
import '../theme/brand_theme.dart';

class RoasChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const RoasChart({super.key, required this.data});

  static double _parse(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

  static Color _roasColor(double roas) {
    if (roas < 1.0) return BrandColors.red;
    if (roas <= 2.0) return BrandColors.gold;
    return BrandColors.emerald;
  }

  static String _formatSpend(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No channel data'));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;

    final sorted = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) => _parse(b['roas']).compareTo(_parse(a['roas'])));

    final maxRoas = sorted.map((e) => _parse(e['roas'])).reduce((a, b) => a > b ? a : b);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final channel = sorted[i]['channel']?.toString() ?? '';
        final roas = _parse(sorted[i]['roas']);
        final spend = _parse(sorted[i]['total_spend']);
        final color = _roasColor(roas);
        final fraction = maxRoas > 0 ? roas / maxRoas : 0.0;

        return Row(
          children: [
            // Channel name
            SizedBox(
              width: 110,
              child: Text(
                channel,
                style: TextStyle(fontSize: 12, color: mutedText, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 10),
            // Bar
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  children: [
                    // Background
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: (isDark ? BrandColors.borderDark : BrandColors.border).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 24,
                      width: constraints.maxWidth * fraction,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _formatSpend(spend),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // 1.0x break-even line
                    if (maxRoas > 1.0)
                      Positioned(
                        left: constraints.maxWidth * (1.0 / maxRoas),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: BrandColors.red.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                );
              }),
            ),
            const SizedBox(width: 8),
            // ROAS value
            SizedBox(
              width: 50,
              child: Text(
                '${roas.toStringAsFixed(1)}x',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}
