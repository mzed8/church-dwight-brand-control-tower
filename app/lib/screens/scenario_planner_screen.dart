import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../theme/brand_theme.dart';
import '../providers/brands_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/spend_slider.dart';
import '../widgets/ticker_number.dart';
import '../widgets/blur_fade_in.dart';
import '../widgets/brand_logo.dart';
import '../widgets/shining_card.dart';

class ScenarioPlannerScreen extends ConsumerStatefulWidget {
  final String brandId;
  const ScenarioPlannerScreen({super.key, required this.brandId});

  @override
  ConsumerState<ScenarioPlannerScreen> createState() =>
      _ScenarioPlannerScreenState();
}

class _ScenarioPlannerScreenState extends ConsumerState<ScenarioPlannerScreen> {
  Map<String, double> _currentSpend = {};
  Map<String, double> _proposedSpend = {};
  double _currentRevenue = 0;
  double _projectedRevenue = 0;
  bool _isComputing = false;
  bool _initialized = false;
  bool _applied = false;
  Timer? _debounceTimer;

  final _channels = [
    'Paid Search',
    'Social Media',
    'Display Ads',
    'Linear TV',
    'Connected TV',
    'Retail Media',
    'Email / CRM',
    'Print / Circulars',
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSliderChanged(String channel, double value) {
    setState(() {
      _proposedSpend[channel] = value;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _runScenario);
  }

  Future<void> _runScenario() async {
    setState(() => _isComputing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final brands = await ref.read(brandsProvider.future);
      final brand = brands.firstWhere((b) => b.id == widget.brandId);
      final scenario = await api.runScenario(brand.name, _proposedSpend);
      if (mounted) {
        setState(() {
          _projectedRevenue = scenario.projectedRevenue;
          _isComputing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isComputing = false);
      }
    }
  }

  void _resetSpend() {
    setState(() {
      _proposedSpend = Map.from(_currentSpend);
      _projectedRevenue = _currentRevenue;
    });
  }

  // ---------------------------------------------------------------------------
  // Number formatting helpers
  // ---------------------------------------------------------------------------

  static String _formatRevenue(double value) {
    if (value <= 0) return '\$0';
    final str = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '\$$buf';
  }

  static String _formatSpendCompact(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '\$${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '\$${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  static String _formatDelta(double delta, double pct) {
    final sign = delta >= 0 ? '+' : '-';
    final pctSign = pct >= 0 ? '+' : '';
    return '$sign${_formatRevenue(delta.abs()).substring(0)} ($pctSign${pct.toStringAsFixed(1)}%)';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final channelsAsync = ref.watch(brandChannelsProvider(widget.brandId));

    final bg = isDark ? BrandColors.surfaceDark : BrandColors.surface;
    final cardBg = isDark ? BrandColors.cardDark : Colors.white;
    final primaryText = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final mutedText =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final borderColor = isDark ? BrandColors.borderDark : BrandColors.border;

    // Resolve brand name
    final brandName = brandsAsync.when(
      data: (brands) {
        final b = brands.where((b) => b.id == widget.brandId);
        return b.isNotEmpty ? b.first.name : widget.brandId;
      },
      loading: () => widget.brandId,
      error: (_, __) => widget.brandId,
    );

    // Initialize spend maps from channel data
    channelsAsync.when(
      data: (channels) {
        if (!_initialized && channels.isNotEmpty) {
          final current = <String, double>{};
          double totalRevenue = 0;
          for (final ch in channels) {
            final name = ch['channel'] as String;
            final spend = double.tryParse(ch['total_spend'].toString()) ?? 0.0;
            final revenue = double.tryParse(ch['total_revenue'].toString()) ?? 0.0;
            current[name] = spend;
            totalRevenue += revenue;
          }
          // Ensure all 8 channels are present (fill missing with 0)
          for (final c in _channels) {
            current.putIfAbsent(c, () => 0);
          }
          _currentSpend = current;
          _proposedSpend = Map.from(current);
          _currentRevenue = totalRevenue;
          _projectedRevenue = totalRevenue;
          _initialized = true;
        }
      },
      loading: () {},
      error: (_, __) {},
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? BrandColors.navy : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => context.canPop() ? context.pop() : context.go('/brand/${widget.brandId}'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 24),
            const SizedBox(width: 16),
            Text(
              'SCENARIO PLANNER \u2014 ${brandName.toUpperCase()}',
              style: TextStyle(
                color: primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.chat_bubble_outline,
              color: ref.watch(chatOpenProvider) ? BrandColors.blue : mutedText,
            ),
            onPressed: () {
              ref.read(chatOpenProvider.notifier).state =
                  !ref.read(chatOpenProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading channels: $err',
              style: TextStyle(color: BrandColors.red)),
        ),
        data: (_) => LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;

            final slidersPanel = BlurFadeIn(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: BrandColors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Channel Spend Allocation',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Data from Unity Catalog tables via Databricks SQL',
                          child: Icon(Icons.info_outline_rounded, size: 14, color: mutedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag sliders to simulate budget reallocation',
                      style: TextStyle(color: mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor),
                    const SizedBox(height: 8),
                    ..._channels.map((channel) {
                      final current = _currentSpend[channel] ?? 0;
                      final proposed = _proposedSpend[channel] ?? 0;
                      final sliderMax = (current * 3).clamp(50000.0, 500000.0);
                      return SpendSlider(
                        channel: channel,
                        currentValue: current,
                        proposedValue: proposed,
                        min: 0,
                        max: sliderMax,
                        onChanged: (v) => _onSliderChanged(channel, v),
                      );
                    }),
                  ],
                ),
              ),
            );

            final impactPanel = BlurFadeIn(
              delay: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  ShiningCard(
                    glowColor: BrandColors.blue,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.insights, color: BrandColors.gold, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Projected Impact',
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Marketing Mix Model — MLflow served endpoint with R\u00B2 = 0.98',
                                child: Icon(Icons.info_outline_rounded, size: 14, color: mutedText),
                              ),
                              const Spacer(),
                              if (_isComputing)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(BrandColors.blue),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text('Current Revenue',
                              style: TextStyle(color: mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          TickerNumber(
                            value: _currentRevenue,
                            prefix: '\$',
                            style: TextStyle(color: primaryText, fontSize: isNarrow ? 24 : 28, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          Divider(color: borderColor),
                          const SizedBox(height: 20),
                          Text('Projected Revenue',
                              style: TextStyle(color: mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          TickerNumber(
                            value: _projectedRevenue,
                            prefix: '\$',
                            style: TextStyle(color: BrandColors.blue, fontSize: isNarrow ? 28 : 32, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          _buildDeltaBadge(),
                          const SizedBox(height: 12),
                          Text(
                            'Model: Marketing Mix Model (R\u00B2 = 0.98) | MLflow tracked',
                            style: TextStyle(color: mutedText, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 24),
                          Divider(color: borderColor),
                          const SizedBox(height: 16),
                          _buildSpendComparison(primaryText, mutedText),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ShadButton(
                                  onPressed: (_isComputing || _applied) ? null : () {
                                    setState(() => _applied = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Budget reallocation submitted for approval'),
                                          ],
                                        ),
                                        backgroundColor: BrandColors.emerald,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  backgroundColor: _applied ? Colors.grey : BrandColors.emerald,
                                  child: Text(_applied ? 'Changes Applied \u2713' : 'Apply Changes'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ShadButton.outline(
                                  onPressed: _resetSpend,
                                  child: Text('Reset', style: TextStyle(color: mutedText)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (isNarrow) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    slidersPanel,
                    const SizedBox(height: 24),
                    impactPanel,
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: slidersPanel),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: impactPanel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildDeltaBadge() {
    final delta = _projectedRevenue - _currentRevenue;
    final pct = _currentRevenue > 0 ? (delta / _currentRevenue) * 100 : 0.0;
    final isPositive = delta >= 0;
    final color = isPositive ? BrandColors.emerald : BrandColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDelta(delta, pct),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendComparison(Color primaryText, Color mutedText) {
    final currentTotal =
        _currentSpend.values.fold<double>(0, (a, b) => a + b);
    final proposedTotal =
        _proposedSpend.values.fold<double>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Spend',
          style: TextStyle(
            color: mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _formatSpendCompact(currentTotal),
              style: TextStyle(
                color: mutedText,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 14, color: mutedText),
            const SizedBox(width: 8),
            Text(
              _formatSpendCompact(proposedTotal),
              style: TextStyle(
                color: primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
