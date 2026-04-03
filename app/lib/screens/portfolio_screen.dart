// ignore: avoid_web_libraries_in_flutter
import "dart:html" as html;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/alert.dart';
import '../models/brand.dart';
import '../providers/alerts_provider.dart';
import '../providers/brands_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/brand_theme.dart';
import '../widgets/blur_fade_in.dart';
import '../widgets/brand_card.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/brand_logo.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/floating_bubbles.dart';
import '../widgets/ticker_number.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: isDark ? BrandColors.surfaceDark : BrandColors.surface,
      appBar: _buildAppBar(context, ref, isDark, theme),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 960;

          if (isWide) {
            return Stack(
              children: [
                Positioned.fill(child: FloatingBubbles(isDark: isDark)),
                Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _PortfolioKpiBar(
                          brandsAsync: brandsAsync,
                          alertsAsync: alertsAsync,
                          isDark: isDark,
                        ),
                        _BrandsGrid(
                          brandsAsync: brandsAsync,
                          isWide: isWide,
                        ),
                        _GovernanceBadge(isDark: isDark),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _AlertsPanel(
                    alertsAsync: alertsAsync,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
              ],
            );
          }

          // Narrow layout: brands grid then alerts below
          return Stack(
            children: [
              Positioned.fill(child: FloatingBubbles(isDark: isDark)),
              SingleChildScrollView(
            child: Column(
              children: [
                _PortfolioKpiBar(
                  brandsAsync: brandsAsync,
                  alertsAsync: alertsAsync,
                  isDark: isDark,
                ),
                _BrandsGrid(
                  brandsAsync: brandsAsync,
                  isWide: isWide,
                ),
                _AlertsPanel(
                  alertsAsync: alertsAsync,
                  isDark: isDark,
                ),
                _GovernanceBadge(isDark: isDark),
              ],
            ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ShadThemeData theme,
  ) {
    return AppBar(
      backgroundColor: isDark ? BrandColors.navy : Colors.white,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      title: const BrandLogo(height: 32, showSubtitle: true),
      actions: [
        // About page
        IconButton(
          icon: Icon(Icons.info_outline_rounded, color: isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary),
          tooltip: "About",
          onPressed: () => html.window.location.href = "landing.html",
        ),
        const SizedBox(width: 4),
        // Dark mode toggle
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            ref.read(isDarkModeProvider.notifier).state = !isDark;
          },
        ),
        const SizedBox(width: 4),
        // Chat button
        IconButton(
          icon: Icon(
            Icons.chat_bubble_outline_rounded,
            color: isDark ? BrandColors.blue : BrandColors.blue,
          ),
          tooltip: 'Open AI assistant',
          onPressed: () {
            ref.read(chatOpenProvider.notifier).state =
                !ref.read(chatOpenProvider);
          },
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark ? BrandColors.borderDark : BrandColors.border,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portfolio KPI Summary Bar
// ---------------------------------------------------------------------------

class _PortfolioKpiBar extends StatelessWidget {
  final AsyncValue<List<Brand>> brandsAsync;
  final AsyncValue<List<Alert>> alertsAsync;
  final bool isDark;

  const _PortfolioKpiBar({
    required this.brandsAsync,
    required this.alertsAsync,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Compute KPIs from loaded data
    final brands = brandsAsync.valueOrNull ?? [];
    final alerts = alertsAsync.valueOrNull ?? [];

    // Weighted average health (weight by health score magnitude)
    double portfolioHealth = 0;
    if (brands.isNotEmpty) {
      final totalWeight = brands.fold<double>(0, (s, b) => s + b.healthScore);
      if (totalWeight > 0) {
        portfolioHealth = brands.fold<double>(
              0,
              (s, b) => s + b.healthScore * b.healthScore,
            ) /
            totalWeight;
      }
    }

    final brandCount = brands.length;

    // Blended ROAS
    double blendedRoas = 0;
    if (brands.isNotEmpty) {
      blendedRoas =
          brands.fold<double>(0, (s, b) => s + b.avgRoas) / brands.length;
    }

    final alertCount = alerts.length;

    final isLoading = brandsAsync.isLoading || alertsAsync.isLoading;

    final infoColor = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Portfolio KPIs',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: infoColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Powered by Databricks SQL + Unity Catalog semantic layer',
                child: Icon(Icons.info_outline_rounded, size: 14, color: infoColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          isLoading
          ? Row(
              children: List.generate(
                4,
                (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ShimmerLoading(height: 88, borderRadius: 14),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: BlurFadeIn(
                    delay: const Duration(milliseconds: 0),
                    child: _KpiGlassCard(
                      icon: Icons.monitor_heart_outlined,
                      value: portfolioHealth,
                      decimals: 1,
                      suffix: '',
                      label: 'Portfolio Health',
                      accentColor: BrandColors.blue,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlurFadeIn(
                    delay: const Duration(milliseconds: 80),
                    child: _KpiGlassCard(
                      icon: Icons.inventory_2_outlined,
                      value: brandCount.toDouble(),
                      decimals: 0,
                      suffix: '',
                      label: 'Brands Monitored',
                      accentColor: BrandColors.gold,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlurFadeIn(
                    delay: const Duration(milliseconds: 160),
                    child: _KpiGlassCard(
                      icon: Icons.trending_up_rounded,
                      value: blendedRoas,
                      decimals: 2,
                      suffix: 'x',
                      label: 'Blended ROAS',
                      accentColor: BrandColors.emerald,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlurFadeIn(
                    delay: const Duration(milliseconds: 240),
                    child: _KpiGlassCard(
                      icon: Icons.notifications_active_outlined,
                      value: alertCount.toDouble(),
                      decimals: 0,
                      suffix: '',
                      label: 'Active Alerts',
                      accentColor: BrandColors.red,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KpiGlassCard extends StatelessWidget {
  final IconData icon;
  final double value;
  final int decimals;
  final String suffix;
  final String label;
  final Color accentColor;
  final bool isDark;

  const _KpiGlassCard({
    required this.icon,
    required this.value,
    required this.decimals,
    required this.suffix,
    required this.label,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? BrandColors.cardDark.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark ? BrandColors.borderDark : BrandColors.border;
    final textPrimary = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final textSecondary =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TickerNumber(
                      value: value,
                      decimals: decimals,
                      suffix: suffix,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Governance Badge
// ---------------------------------------------------------------------------

class _GovernanceBadge extends StatelessWidget {
  final bool isDark;
  const _GovernanceBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, size: 13, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            'Data: serverless_stable_ocafq5_catalog.chd_demo  |  Unity Catalog Governed',
            style: TextStyle(
              fontSize: 11,
              color: textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brands grid
// ---------------------------------------------------------------------------

class _BrandsGrid extends StatelessWidget {
  final AsyncValue<List<Brand>> brandsAsync;
  final bool isWide;

  const _BrandsGrid({required this.brandsAsync, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return brandsAsync.when(
      loading: () => _buildLoading(),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Failed to load brands: $err',
            style: TextStyle(color: BrandColors.red),
          ),
        ),
      ),
      data: (brands) => _buildGrid(brands),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: List.generate(
          5,
          (_) => ShimmerLoading(
            width: 280,
            height: 220,
            borderRadius: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<Brand> brands) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: brands.asMap().entries.map((entry) {
          final index = entry.key;
          final brand = entry.value;
          return BlurFadeIn(
            delay: Duration(milliseconds: 100 * index),
            child: BrandCard(brand: brand),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alerts panel
// ---------------------------------------------------------------------------

class _AlertsPanel extends ConsumerWidget {
  final AsyncValue<List<Alert>> alertsAsync;
  final bool isDark;

  const _AlertsPanel({required this.alertsAsync, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final textSecondary = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final panelBg = isDark ? BrandColors.cardDark : Colors.white;
    final borderColor = isDark ? BrandColors.borderDark : BrandColors.border;
    final dispatched = ref.watch(dispatchedAlertsProvider);
    final dispatchedIds = dispatched.map((d) => d.alertId).toSet();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Alerts Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined, size: 18, color: BrandColors.red),
                const SizedBox(width: 8),
                Text('Active Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Generated by Multi-Agent Supervisor with Genie Space + Knowledge Assistant',
                  child: Icon(Icons.info_outline_rounded, size: 14, color: textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          // Active alert list (filtered)
          alertsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(height: 72, borderRadius: 12),
              ))),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Failed to load alerts', style: TextStyle(color: BrandColors.red, fontSize: 13)),
            ),
            data: (alerts) {
              final active = alerts.where((a) => !dispatchedIds.contains(a.id)).toList();
              if (active.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('All alerts dispatched \u2713', style: TextStyle(color: textSecondary, fontSize: 13))),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: active.asMap().entries.map((entry) {
                  return BlurFadeIn(
                    delay: Duration(milliseconds: 200 + 100 * entry.key),
                    child: _AlertTile(alert: entry.value, isDark: isDark, showDivider: entry.key < active.length - 1),
                  );
                }).toList(),
              );
            },
          ),
          // Recently Dispatched section
          if (dispatched.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: BrandColors.emerald),
                  const SizedBox(width: 8),
                  Text('Recently Dispatched', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
                ],
              ),
            ),
            ...dispatched.map((d) => _DispatchedTile(dispatched: d, isDark: isDark)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DispatchedTile extends StatelessWidget {
  final DispatchedAlert dispatched;
  final bool isDark;
  const _DispatchedTile({required this.dispatched, required this.isDark});

  Color get _actionColor {
    switch (dispatched.action) {
      case 'approved': return BrandColors.emerald;
      case 'modified': return BrandColors.blue;
      case 'dismissed': return BrandColors.textSecondary;
      default: return BrandColors.textSecondary;
    }
  }

  IconData get _actionIcon {
    switch (dispatched.action) {
      case 'approved': return Icons.check_circle;
      case 'modified': return Icons.tune;
      case 'dismissed': return Icons.cancel_outlined;
      default: return Icons.circle;
    }
  }

  String get _actionLabel {
    switch (dispatched.action) {
      case 'approved': return 'Approved';
      case 'modified': return 'Sent to Scenario';
      case 'dismissed': return 'Dismissed';
      default: return dispatched.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(_actionIcon, size: 14, color: _actionColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dispatched.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary)),
                Text(dispatched.brandName, style: TextStyle(fontSize: 10, color: textSecondary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_actionLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _actionColor)),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Alert alert;
  final bool isDark;
  final bool showDivider;

  const _AlertTile({
    required this.alert,
    required this.isDark,
    this.showDivider = true,
  });

  Color get _severityColor {
    switch (alert.severity) {
      case 'critical':
        return BrandColors.red;
      case 'warning':
        return BrandColors.gold;
      case 'opportunity':
        return BrandColors.emerald;
      default:
        return BrandColors.blue;
    }
  }

  String get _severityLabel {
    switch (alert.severity) {
      case 'critical':
        return 'CRITICAL';
      case 'warning':
        return 'WARNING';
      case 'opportunity':
        return 'OPPORTUNITY';
      default:
        return alert.severity.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final textSecondary = isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final borderColor = isDark ? BrandColors.borderDark : BrandColors.border;

    return Column(
      children: [
        InkWell(
          onTap: () => context.go('/brand/${alert.brandId}'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: PulsingDot(color: _severityColor, size: 10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Brand name + severity badge
                      Row(
                        children: [
                          Text(
                            alert.brandName,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _severityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _severityLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _severityColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 42,
            endIndent: 20,
            color: borderColor,
          ),
      ],
    );
  }
}
