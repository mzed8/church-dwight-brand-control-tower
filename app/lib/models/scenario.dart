class Scenario {
  final String brandId;
  final Map<String, double> currentSpend;
  final Map<String, double> proposedSpend;
  final double currentRevenue;
  final double projectedRevenue;

  Scenario({
    required this.brandId,
    required this.currentSpend,
    required this.proposedSpend,
    required this.currentRevenue,
    required this.projectedRevenue,
  });

  double get revenueDelta => projectedRevenue - currentRevenue;
  double get revenueDeltaPct =>
      currentRevenue > 0 ? (revenueDelta / currentRevenue) * 100 : 0;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      brandId: json['brandId']?.toString() ?? '',
      currentSpend: _parseSpendMap(json['currentSpend']),
      proposedSpend: _parseSpendMap(json['proposedSpend']),
      currentRevenue: _toDouble(json['currentRevenue']),
      projectedRevenue: _toDouble(json['projectedRevenue']),
    );
  }

  static Map<String, double> _parseSpendMap(dynamic raw) {
    if (raw == null) return {};
    final map = raw as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(key, _toDouble(value)));
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brandId,
      'proposedSpend': proposedSpend,
    };
  }
}
