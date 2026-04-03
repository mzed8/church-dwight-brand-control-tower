import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../theme/brand_theme.dart';
import 'pulsing_dot.dart';

/// Card displaying an alert with severity indicator, actions, and state management.
class AlertCard extends ConsumerStatefulWidget {
  final Alert alert;

  const AlertCard({super.key, required this.alert});

  @override
  ConsumerState<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends ConsumerState<AlertCard>
    with SingleTickerProviderStateMixin {
  bool _showCheck = false;

  Color _severityColor() {
    switch (widget.alert.severity) {
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

  Color _severityBg() {
    switch (widget.alert.severity) {
      case 'critical':
        return BrandColors.redLight;
      case 'warning':
        return BrandColors.goldLight;
      case 'opportunity':
        return BrandColors.emeraldLight;
      default:
        return BrandColors.blueLight;
    }
  }

  String _severityLabel() {
    switch (widget.alert.severity) {
      case 'critical':
        return 'CRITICAL';
      case 'warning':
        return 'WARNING';
      case 'opportunity':
        return 'OPPORTUNITY';
      default:
        return widget.alert.severity.toUpperCase();
    }
  }

  void _handleApprove() {
    ref.read(alertStatusProvider(widget.alert.id).notifier).state = 'approved';
    ref.read(dispatchedAlertsProvider.notifier).dispatch(widget.alert, 'approved');
    setState(() => _showCheck = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showCheck = false);
    });
  }

  void _handleDismiss() {
    ref.read(alertStatusProvider(widget.alert.id).notifier).state = 'dismissed';
    ref.read(dispatchedAlertsProvider.notifier).dispatch(widget.alert, 'dismissed');
  }

  void _handleModify() {
    ref.read(dispatchedAlertsProvider.notifier).dispatch(widget.alert, 'modified');
    context.go('/brand/${widget.alert.brandId}/scenario');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(alertStatusProvider(widget.alert.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isResolved = status == 'approved' || status == 'dismissed';
    final sevColor = _severityColor();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: isResolved ? 0.5 : 1.0,
      child: ShadCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: pulsing dot + severity badge + brand name + status
            Row(
              children: [
                if (!isResolved) PulsingDot(color: sevColor, size: 10),
                if (!isResolved) const SizedBox(width: 10),
                ShadBadge(
                  backgroundColor: _severityBg(),
                  foregroundColor: sevColor,
                  child: Text(
                    _severityLabel(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.alert.brandName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? BrandColors.textSecondaryDark
                        : BrandColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (isResolved)
                  ShadBadge(
                    backgroundColor:
                        status == 'approved' ? BrandColors.emeraldLight : BrandColors.border,
                    foregroundColor:
                        status == 'approved' ? BrandColors.emerald : BrandColors.textSecondary,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == 'approved' ? Icons.check_circle : Icons.cancel,
                          size: 12,
                          color: status == 'approved'
                              ? BrandColors.emerald
                              : BrandColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status == 'approved' ? 'Approved' : 'Dismissed',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                if (_showCheck)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, value, _) => Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.check_circle,
                        color: BrandColors.emerald,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              widget.alert.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? BrandColors.textDark : BrandColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            // Summary
            Text(
              widget.alert.summary,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: isDark
                    ? BrandColors.textSecondaryDark
                    : BrandColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Recommendation box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? BrandColors.blue.withValues(alpha: 0.1)
                    : BrandColors.blueLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: BrandColors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: BrandColors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.alert.recommendation,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? BrandColors.textDark : BrandColors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            if (!isResolved) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  ShadButton(
                    backgroundColor: BrandColors.emerald,
                    foregroundColor: Colors.white,
                    size: ShadButtonSize.sm,
                    onPressed: _handleApprove,
                    leading: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check, size: 14),
                    ),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    foregroundColor: BrandColors.blue,
                    onPressed: _handleModify,
                    leading: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.tune, size: 14),
                    ),
                    child: const Text('Modify \u2192 Scenario'),
                  ),
                  const SizedBox(width: 8),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    foregroundColor: isDark
                        ? BrandColors.textSecondaryDark
                        : BrandColors.textSecondary,
                    onPressed: _handleDismiss,
                    leading: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.close, size: 14),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
