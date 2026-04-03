import 'package:flutter/material.dart';
import '../theme/brand_theme.dart';

/// Channel efficiency chart showing spend bars with ROAS indicators.
class ChannelEfficiencyChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const ChannelEfficiencyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No channel data available'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final secondaryColor =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;

    // Parse and sort by revenue descending
    final parsed = data.map((row) {
      final channel = row['channel']?.toString() ?? 'Unknown';
      final spend =
          double.tryParse(row['total_spend']?.toString() ?? '') ?? 0.0;
      final revenue =
          double.tryParse(row['total_revenue']?.toString() ?? '') ?? 0.0;
      final roas = double.tryParse(row['roas']?.toString() ?? '') ?? 0.0;
      return _ChannelRow(
          channel: channel, spend: spend, revenue: revenue, roas: roas);
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final maxSpend =
        parsed.fold<double>(0, (m, r) => r.spend > m ? r.spend : m);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Channel',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor)),
              ),
              Expanded(
                flex: 4,
                child: Text('Spend',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor)),
              ),
              SizedBox(
                width: 60,
                child: Text('ROAS',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: parsed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final row = parsed[index];
              final barFraction = maxSpend > 0
                  ? (row.spend / maxSpend).clamp(0.0, 1.0)
                  : 0.0;

              // ROAS color coding
              Color roasColor;
              if (row.roas >= 2.0) {
                roasColor = BrandColors.emerald;
              } else if (row.roas >= 1.0) {
                roasColor = BrandColors.gold;
              } else {
                roasColor = BrandColors.red;
              }

              return Row(
                children: [
                  // Channel name
                  Expanded(
                    flex: 3,
                    child: Text(
                      _shortenChannel(row.channel),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Spend bar
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 18,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? BrandColors.borderDark
                                            : BrandColors.border)
                                        .withValues(alpha: 0.3),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                  height: 18,
                                  width:
                                      constraints.maxWidth * barFraction,
                                  decoration: BoxDecoration(
                                    color: BrandColors.blue.withValues(
                                        alpha: isDark ? 0.7 : 0.8),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding:
                                      const EdgeInsets.only(left: 4),
                                  child: barFraction > 0.25
                                      ? Text(
                                          _formatDollars(row.spend),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                        if (barFraction <= 0.25)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              _formatDollars(row.spend),
                              style: TextStyle(
                                fontSize: 9,
                                color: secondaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ROAS value
                  SizedBox(
                    width: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: roasColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${row.roas.toStringAsFixed(2)}x',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: roasColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static String _shortenChannel(String channel) {
    return channel
        .replaceAll('Walmart Connect', 'Walmart')
        .replaceAll('Influencer Marketing', 'Influencer')
        .replaceAll('Paid Social', 'Social')
        .replaceAll('Paid Search', 'Search')
        .replaceAll('Display Ads', 'Display')
        .replaceAll('Email Marketing', 'Email');
  }

  static String _formatDollars(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _ChannelRow {
  final String channel;
  final double spend;
  final double revenue;
  final double roas;

  const _ChannelRow({
    required this.channel,
    required this.spend,
    required this.revenue,
    required this.roas,
  });
}
