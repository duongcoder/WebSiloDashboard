class Silo {
  final String id;
  final double weight;
  final double level;
  final String indicatorId;
  final String indicatorPort;
  final double indicatorMaxLoad;
  final String controllerIp;
  final int controllerPort;
  final String controllerSn;

  Silo({
    required this.id,
    required this.weight,
    required this.level,
    required this.indicatorId,
    required this.indicatorPort,
    required this.indicatorMaxLoad,
    required this.controllerIp,
    required this.controllerPort,
    required this.controllerSn,
  });

  factory Silo.fromJson(Map<String, dynamic> json) {
    return Silo(
      id: json['id'],
      weight: (json['weight'] as num).toDouble(),
      level: (json['level'] as num).toDouble(),
      indicatorId: json['indicatorId'],
      indicatorPort: json['indicatorPort'],
      indicatorMaxLoad: (json['indicatorMaxLoad'] as num).toDouble(),
      controllerIp: json['controllerIp'],
      controllerPort: json['controllerPort'] as int,
      controllerSn: json['controllerSn'],
    );
  }
}
