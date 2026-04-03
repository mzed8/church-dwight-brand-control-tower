class Brand {
  final String id;
  final String name;
  final String tagline;
  final double healthScore;
  final double healthDelta;
  final double avgRoas;
  final List<double> healthTrend;

  Brand({
    required this.id,
    required this.name,
    required this.tagline,
    required this.healthScore,
    required this.healthDelta,
    required this.avgRoas,
    required this.healthTrend,
  });

  String get status {
    if (healthScore > 75) return 'healthy';
    if (healthScore >= 60) return 'watch';
    return 'critical';
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      healthScore: _toDouble(json['healthScore']),
      healthDelta: _toDouble(json['healthDelta']),
      avgRoas: _toDouble(json['avgRoas']),
      healthTrend: ((json['healthTrend'] ?? []) as List<dynamic>)
          .map((e) => _toDouble(e))
          .toList(),
    );
  }
}
