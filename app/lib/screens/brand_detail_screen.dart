import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/brand.dart';
import '../providers/alerts_provider.dart';
import '../providers/brands_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/brand_theme.dart';
import '../widgets/alert_card.dart';
import '../widgets/blur_fade_in.dart';
import '../widgets/health_trend_chart.dart';
import '../widgets/roas_chart.dart';
import '../widgets/channel_efficiency_chart.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/social_engagement_chart.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ticker_number.dart';

/// Brand detail screen showing health metrics, charts, and alerts.
class BrandDetailScreen extends ConsumerWidget {
  final String brandId;
  const BrandDetailScreen({super.key, required this.brandId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final healthAsync = ref.watch(brandHealthProvider(brandId));
    final channelsAsync = ref.watch(brandChannelsProvider(brandId));
    final socialAsync = ref.watch(brandSocialProvider(brandId));
    final alertsAsync = ref.watch(alertsProvider);

    final bgColor = isDark ? BrandColors.surfaceDark : BrandColors.surface;
    final textColor = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final secondaryColor =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final cardColor = isDark ? BrandColors.cardDark : Colors.white;

    // Find the brand from the brands list
    final brand = brandsAsync.whenOrNull<Brand?>(
      data: (brands) {
        try {
          return brands.firstWhere((b) => b.id == brandId);
        } catch (_) {
          return null;
        }
      },
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // -------------------------------------------------------
          // App bar
          // -------------------------------------------------------
          SliverAppBar(
            pinned: true,
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor),
              onPressed: () => context.go('/'),
            ),
            title: brand != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(height: 24),
                      const SizedBox(width: 16),
                      Text(
                        brand.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  )
                : const SizedBox(),
            actions: [
              if (brand != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _StatusBadge(status: brand.status),
                ),
              IconButton(
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: secondaryColor,
                ),
                onPressed: () {
                  ref.read(chatOpenProvider.notifier).state =
                      !ref.read(chatOpenProvider);
                },
                tooltip: 'Toggle AI assistant',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // -------------------------------------------------------
          // Body content
          // -------------------------------------------------------
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- KPI row ---
                BlurFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: _buildKpiRow(
                    context,
                    brand: brand,
                    healthAsync: healthAsync,
                    isDark: isDark,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                    cardColor: cardColor,
                  ),
                ),

                const SizedBox(height: 24),

                // --- 2x2 chart grid ---
                BlurFadeIn(
                  delay: const Duration(milliseconds: 250),
                  child: _buildChartGrid(
                    context,
                    healthAsync: healthAsync,
                    channelsAsync: channelsAsync,
                    socialAsync: socialAsync,
                    isDark: isDark,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                    cardColor: cardColor,
                  ),
                ),

                const SizedBox(height: 32),

                // --- Alerts section ---
                BlurFadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: _buildAlertSection(
                    context,
                    alertsAsync: alertsAsync,
                    isDark: isDark,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                  ),
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // KPI row
  // -------------------------------------------------------
  Widget _buildKpiRow(
    BuildContext context, {
    required Brand? brand,
    required AsyncValue<List<Map<String, dynamic>>> healthAsync,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required Color cardColor,
  }) {
    if (brand == null) {
      return Row(
        children: List.generate(
          3,
          (_) => const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: ShimmerLoading(height: 120),
            ),
          ),
        ),
      );
    }

    // Compute total reviews from health data
    final totalReviews = healthAsync.whenOrNull<int>(
      data: (data) => data.fold<int>(
        0,
        (sum, row) => sum + (int.tryParse(row['review_count']?.toString() ?? '') ?? 0),
      ),
    );

    final healthScoreCard = _KpiCard(
            cardColor: cardColor,
            isDark: isDark,
            label: 'Health Score',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _HealthGauge(score: brand.healthScore, isDark: isDark),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TickerNumber(
                      value: brand.healthScore,
                      decimals: 1,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          brand.healthDelta >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 14,
                          color: brand.healthDelta >= 0
                              ? BrandColors.emerald
                              : BrandColors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${brand.healthDelta >= 0 ? '+' : ''}${brand.healthDelta.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: brand.healthDelta >= 0
                                ? BrandColors.emerald
                                : BrandColors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );

    final roasCard = _KpiCard(
            cardColor: cardColor,
            isDark: isDark,
            label: 'Average ROAS',
            child: TickerNumber(
              value: brand.avgRoas,
              suffix: 'x',
              decimals: 2,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: brand.avgRoas >= 2.0
                    ? BrandColors.emerald
                    : brand.avgRoas >= 1.0
                        ? BrandColors.gold
                        : BrandColors.red,
              ),
            ),
          );

    final reviewsCard = _KpiCard(
            cardColor: cardColor,
            isDark: isDark,
            label: 'Reviews (90d)',
            child: totalReviews != null
                ? TickerNumber(
                    value: totalReviews.toDouble(),
                    decimals: 0,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  )
                : const ShimmerLoading(height: 40, width: 100),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Stack vertically on narrow screens
          return Column(
            children: [
              healthScoreCard,
              const SizedBox(height: 12),
              roasCard,
              const SizedBox(height: 12),
              reviewsCard,
            ],
          );
        }
        // Horizontal on wider screens
        return Row(
          children: [
            Expanded(child: healthScoreCard),
            const SizedBox(width: 16),
            Expanded(child: roasCard),
            const SizedBox(width: 16),
            Expanded(child: reviewsCard),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------
  // 2x2 chart grid
  // -------------------------------------------------------
  Widget _buildChartGrid(
    BuildContext context, {
    required AsyncValue<List<Map<String, dynamic>>> healthAsync,
    required AsyncValue<List<Map<String, dynamic>>> channelsAsync,
    required AsyncValue<List<Map<String, dynamic>>> socialAsync,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required Color cardColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 2 : 1;
        const spacing = 16.0;

        if (crossCount == 2) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChartCard(
                      cardColor: cardColor,
                      isDark: isDark,
                      textColor: textColor,
                      title: 'Health Score Trend',
                      icon: Icons.show_chart_rounded,
                      tooltipMessage: 'AI Functions (ai_query) — zero-training sentiment scoring in SQL',
                      chartDescription: 'This chart tracks the brand\'s overall health score (0–100) over the past 90 days. The score is derived from AI-scored sentiment across Amazon reviews, social media, and retailer feedback. The dashed red line at 60 marks the "Critical" threshold — scores below this require immediate attention. The dashed gold line at 75 marks the "Watch" threshold. A sustained downward trend signals emerging consumer dissatisfaction.',
                      child: SizedBox(
                        height: 280,
                        child: healthAsync.when(
                          data: (data) => HealthTrendChart(data: data),
                          loading: () =>
                              const ShimmerLoading(height: 260),
                          error: (e, _) => Center(
                            child: Text('Error: $e',
                                style: const TextStyle(
                                    color: BrandColors.red)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: _ChartCard(
                      cardColor: cardColor,
                      isDark: isDark,
                      textColor: textColor,
                      title: 'ROAS by Channel',
                      icon: Icons.bar_chart_rounded,
                      tooltipMessage: 'Marketing Mix Model — MLflow tracked, Unity Catalog registered',
                      chartDescription: 'Return on Ad Spend (ROAS) measures how much revenue each dollar of marketing spend generates. Channels are sorted highest-first. Green bars (>2.0x) are high-performing — every \$1 spent returns >\$2 in revenue. Gold bars (1.0–2.0x) are breaking even or slightly profitable. Red bars (<1.0x) are losing money. The spend amount inside each bar shows total weekly investment. Compare ROAS across channels to identify where to shift budget for maximum impact.',
                      child: SizedBox(
                        height: 280,
                        child: channelsAsync.when(
                          data: (data) => RoasChart(data: data),
                          loading: () =>
                              const ShimmerLoading(height: 260),
                          error: (e, _) => Center(
                            child: Text('Error: $e',
                                style: const TextStyle(
                                    color: BrandColors.red)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChartCard(
                      cardColor: cardColor,
                      isDark: isDark,
                      textColor: textColor,
                      title: 'Channel Efficiency',
                      icon: Icons.storefront_rounded,
                      tooltipMessage: 'Databricks SQL Warehouse — serverless compute',
                      chartDescription: 'Channel Efficiency compares spend allocation against return for each marketing channel. The blue bar shows total spend — longer bars mean more budget allocated. The ROAS dot on the right shows efficiency: green dots (>2.0x) indicate high-return channels, gold dots (1.0–2.0x) are moderate, and red dots (<1.0x) are underperforming. Look for mismatches — high spend with low ROAS signals an opportunity to reallocate budget to more efficient channels.',
                      child: SizedBox(
                        height: 280,
                        child: channelsAsync.when(
                          data: (data) => ChannelEfficiencyChart(data: data),
                          loading: () =>
                              const ShimmerLoading(height: 260),
                          error: (e, _) => Center(
                            child: Text('Error: \$e',
                                style: const TextStyle(
                                    color: BrandColors.red)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: _ChartCard(
                      cardColor: cardColor,
                      isDark: isDark,
                      textColor: textColor,
                      title: 'Social Engagement',
                      icon: Icons.people_outline_rounded,
                      tooltipMessage: 'Delta Lake Gold tables — medallion architecture',
                      chartDescription: 'Social Engagement tracks daily engagement volume (likes, comments, shares, mentions) across four platforms: Instagram, TikTok, Twitter/X, and Reddit. Each colored line represents one platform. Spikes indicate viral moments or trending content — these are opportunities to amplify with paid spend. The legend at the bottom shows platform totals. Compare trends across platforms to identify where your brand is gaining or losing organic traction.',
                      child: SizedBox(
                        height: 280,
                        child: socialAsync.when(
                          data: (data) => SocialEngagementChart(data: data),
                          loading: () =>
                              const ShimmerLoading(height: 260),
                          error: (e, _) => Center(
                            child: Text('Error: \$e',
                                style: const TextStyle(
                                    color: BrandColors.red)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // Single column for narrow screens
        return Column(
          children: [
            _ChartCard(
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              title: 'Health Score Trend',
              icon: Icons.show_chart_rounded,
              tooltipMessage: 'AI Functions (ai_query) — zero-training sentiment scoring in SQL',
              chartDescription: 'This chart tracks the brand\'s overall health score (0–100) over the past 90 days. The score is derived from AI-scored sentiment across Amazon reviews, social media, and retailer feedback. The dashed red line at 60 marks the "Critical" threshold — scores below this require immediate attention. The dashed gold line at 75 marks the "Watch" threshold. A sustained downward trend signals emerging consumer dissatisfaction.',
              child: SizedBox(
                height: 280,
                child: healthAsync.when(
                  data: (data) => HealthTrendChart(data: data),
                  loading: () => const ShimmerLoading(height: 260),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: BrandColors.red)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: spacing),
            _ChartCard(
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              title: 'ROAS by Channel',
              icon: Icons.bar_chart_rounded,
              tooltipMessage: 'Marketing Mix Model — MLflow tracked, Unity Catalog registered',
              chartDescription: 'Return on Ad Spend (ROAS) measures how much revenue each dollar of marketing spend generates. Channels are sorted highest-first. Green bars (>2.0x) are high-performing — every \$1 spent returns >\$2 in revenue. Gold bars (1.0–2.0x) are breaking even or slightly profitable. Red bars (<1.0x) are losing money. The spend amount inside each bar shows total weekly investment. Compare ROAS across channels to identify where to shift budget for maximum impact.',
              child: SizedBox(
                height: 280,
                child: channelsAsync.when(
                  data: (data) => RoasChart(data: data),
                  loading: () => const ShimmerLoading(height: 260),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: BrandColors.red)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: spacing),
            _ChartCard(
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              title: 'Channel Efficiency',
              icon: Icons.storefront_rounded,
              tooltipMessage: 'Databricks SQL Warehouse — serverless compute',
              chartDescription: 'Channel Efficiency compares spend allocation against return for each marketing channel. The blue bar shows total spend — longer bars mean more budget allocated. The ROAS dot on the right shows efficiency: green dots (>2.0x) indicate high-return channels, gold dots (1.0–2.0x) are moderate, and red dots (<1.0x) are underperforming. Look for mismatches — high spend with low ROAS signals an opportunity to reallocate budget to more efficient channels.',
              child: SizedBox(
                height: 280,
                child: channelsAsync.when(
                  data: (data) => ChannelEfficiencyChart(data: data),
                  loading: () => const ShimmerLoading(height: 260),
                  error: (e, _) => Center(
                    child: Text('Error: \$e',
                        style: const TextStyle(color: BrandColors.red)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: spacing),
            _ChartCard(
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              title: 'Social Engagement',
              icon: Icons.people_outline_rounded,
              tooltipMessage: 'Delta Lake Gold tables — medallion architecture',
              chartDescription: 'Social Engagement tracks daily engagement volume (likes, comments, shares, mentions) across four platforms: Instagram, TikTok, Twitter/X, and Reddit. Each colored line represents one platform. Spikes indicate viral moments or trending content — these are opportunities to amplify with paid spend. The legend at the bottom shows platform totals. Compare trends across platforms to identify where your brand is gaining or losing organic traction.',
              child: SizedBox(
                height: 280,
                child: socialAsync.when(
                  data: (data) => SocialEngagementChart(data: data),
                  loading: () => const ShimmerLoading(height: 260),
                  error: (e, _) => Center(
                    child: Text('Error: \$e',
                        style: const TextStyle(color: BrandColors.red)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------
  // Alert section
  // -------------------------------------------------------
  Widget _buildAlertSection(
    BuildContext context, {
    required AsyncValue<List<dynamic>> alertsAsync,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                size: 20, color: BrandColors.gold),
            const SizedBox(width: 8),
            Text(
              'Active Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Agent Bricks — Multi-Agent Supervisor orchestrating Genie + Knowledge Assistant',
              child: Icon(Icons.info_outline_rounded, size: 14, color: secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        alertsAsync.when(
          data: (alerts) {
            final brandAlerts =
                alerts.where((a) => a.brandId == brandId).toList();
            if (brandAlerts.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? BrandColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark ? BrandColors.borderDark : BrandColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 40, color: BrandColors.emerald),
                    const SizedBox(height: 12),
                    Text(
                      'No active alerts',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: brandAlerts
                  .map((alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AlertCard(alert: alert),
                      ))
                  .toList(),
            );
          },
          loading: () => Column(
            children: List.generate(
              2,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(height: 180),
              ),
            ),
          ),
          error: (e, _) => Text(
            'Failed to load alerts: $e',
            style: const TextStyle(color: BrandColors.red),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Private helper widgets
// =============================================================

/// KPI metric card.
class _KpiCard extends StatelessWidget {
  final Color cardColor;
  final bool isDark;
  final String label;
  final Widget child;

  const _KpiCard({
    required this.cardColor,
    required this.isDark,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? BrandColors.borderDark : BrandColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? BrandColors.textSecondaryDark
                  : BrandColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Chart card wrapper with title.
class _ChartCard extends StatelessWidget {
  final Color cardColor;
  final bool isDark;
  final Color textColor;
  final String title;
  final IconData icon;
  final Widget child;
  final String? tooltipMessage;
  final String? chartDescription;

  const _ChartCard({
    required this.cardColor,
    required this.isDark,
    required this.textColor,
    required this.title,
    required this.icon,
    required this.child,
    this.tooltipMessage,
    this.chartDescription,
  });

  void _showExpandedChart(BuildContext context) {
    final mutedColor = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final borderColor = isDark ? BrandColors.borderDark : BrandColors.border;

    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final hasDescription = chartDescription != null && chartDescription!.isNotEmpty;
        return Dialog(
          backgroundColor: cardColor,
          insetPadding: EdgeInsets.all(size.width * 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: BrandColors.blue),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: mutedColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              SizedBox(
                height: hasDescription ? size.height * 0.6 : size.height * 0.7,
                width: size.width * 0.85,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
              if (hasDescription) ...[
                Divider(height: 1, color: borderColor),
                Container(
                  width: size.width * 0.85,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: BrandColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          chartDescription!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? BrandColors.borderDark : BrandColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: BrandColors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (tooltipMessage != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: tooltipMessage!,
                  child: Icon(Icons.info_outline_rounded, size: 14, color: mutedColor),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(Icons.open_in_full, size: 16, color: mutedColor),
                onPressed: () => _showExpandedChart(context),
                tooltip: 'Expand',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Mini arc gauge for health score.
class _HealthGauge extends StatelessWidget {
  final double score;
  final bool isDark;

  const _HealthGauge({required this.score, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _GaugePainter(
          score: score,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final bool isDark;

  _GaugePainter({required this.score, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    final radius = size.width * 0.42;
    const startAngle = 3.9; // ~225 degrees
    const sweepTotal = 2.44; // ~140 degrees arc

    // Background arc
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? BrandColors.borderDark : BrandColors.border)
          .withValues(alpha: 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Value arc
    Color arcColor;
    if (score >= 75) {
      arcColor = BrandColors.emerald;
    } else if (score >= 60) {
      arcColor = BrandColors.gold;
    } else {
      arcColor = BrandColors.red;
    }

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    final valueSweep = sweepTotal * (score / 100).clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      valueSweep,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.score != score || old.isDark != isDark;
}

/// Status badge for brand health status.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'healthy':
        bg = BrandColors.emeraldLight;
        fg = BrandColors.emerald;
        label = 'Healthy';
      case 'watch':
        bg = BrandColors.goldLight;
        fg = BrandColors.gold;
        label = 'Watch';
      case 'critical':
        bg = BrandColors.redLight;
        fg = BrandColors.red;
        label = 'Critical';
      default:
        bg = BrandColors.blueLight;
        fg = BrandColors.blue;
        label = status;
    }

    return ShadBadge(
      backgroundColor: bg,
      foregroundColor: fg,
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}


