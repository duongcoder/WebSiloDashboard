class Silo {
  final String id;
  final double weight;
  final double level;
  final String indicatorId;
  final String indicatorPort;
  final double indicatorMaxLoad;
  final String controllerIp;
  final String controllerPort;
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

  factory Silo.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String toStringOrEmpty(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    return Silo(
      id: toStringOrEmpty(map['id']),
      weight: toDouble(map['weight']),
      level: toDouble(map['level']),
      indicatorId: toStringOrEmpty(map['indicatorId']),
      indicatorPort: toStringOrEmpty(map['indicatorPort']),
      indicatorMaxLoad: toDouble(map['indicatorMaxLoad']),
      controllerIp: toStringOrEmpty(map['controllerIp']),
      controllerPort: toStringOrEmpty(map['controllerPort']),
      controllerSn: toStringOrEmpty(map['controllerSn']),
    );
  }
}

