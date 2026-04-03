class Alert {
  final String id;
  final String brandId;
  final String brandName;
  final String severity;
  final String title;
  final String summary;
  final String recommendation;
  final Map<String, dynamic> metrics;
  String status;

  Alert({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.severity,
    required this.title,
    required this.summary,
    required this.recommendation,
    required this.metrics,
    this.status = 'pending',
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id']?.toString() ?? '',
      brandId: json['brandId']?.toString() ?? '',
      brandName: json['brandName']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'warning',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}
