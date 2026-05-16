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
      id: json['id']?.toString() ?? 'unknown_edge',
      fromId: (json['from'] ?? json['from_id'])?.toString() ?? 'unknown_from',
      toId: (json['to'] ?? json['to_id'])?.toString() ?? 'unknown_to',
      weight: ((json['w'] ?? json['weight']) as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'from': fromId, 'to': toId, 'w': weight};
  }
}
