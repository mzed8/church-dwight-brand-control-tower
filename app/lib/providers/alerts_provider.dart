import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert.dart';
import 'brands_provider.dart';

final alertsProvider = FutureProvider<List<Alert>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getAlerts();
});

// Track alert status changes locally
final alertStatusProvider = StateProvider.family<String, String>((ref, alertId) => 'pending');

// Track dispatched alerts: alertId → {action, timestamp}
class DispatchedAlert {
  final String alertId;
  final String brandName;
  final String title;
  final String severity;
  final String action; // "approved", "modified", "dismissed"
  final DateTime timestamp;

  DispatchedAlert({
    required this.alertId,
    required this.brandName,
    required this.title,
    required this.severity,
    required this.action,
    required this.timestamp,
  });
}

class DispatchedAlertsNotifier extends StateNotifier<List<DispatchedAlert>> {
  DispatchedAlertsNotifier() : super([]);

  void dispatch(Alert alert, String action) {
    state = [
      DispatchedAlert(
        alertId: alert.id,
        brandName: alert.brandName,
        title: alert.title,
        severity: alert.severity,
        action: action,
        timestamp: DateTime.now(),
      ),
      ...state,
    ];
  }
}

final dispatchedAlertsProvider =
    StateNotifierProvider<DispatchedAlertsNotifier, List<DispatchedAlert>>(
        (ref) => DispatchedAlertsNotifier());
