class EdgeModel {
  final String id;
  final String fromId;
  final String toId;
  final double weight;

  EdgeModel({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.weight,
  });

  factory EdgeModel.fromJson(Map<String, dynamic> json) {
    return EdgeModel(
      id: json['id'] as String,
      fromId: json['from'] ?? json['from_id'], // Handle both formats if needed
      toId: json['to'] ?? json['to_id'],
      weight: (json['w'] ?? json['weight'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'from': fromId, 'to': toId, 'w': weight};
  }
}
