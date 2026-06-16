class Silo {
  final String id;
  final double weight;
  final double level;

  Silo({
    required this.id,
    required this.weight,
    required this.level,
  });

  factory Silo.fromJson(Map<String, dynamic> json) {
    return Silo(
      id: json['id'] ?? '',
      weight: (json['weight'] as num).toDouble(),
      level: (json['level'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weight': weight,
      'level': level,
    };
  }
}
