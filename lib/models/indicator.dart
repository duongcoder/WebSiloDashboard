class Indicator {
  String indicatorId;
  String name;
  String port;
  int baudRate;

  Indicator({
    required this.indicatorId,
    required this.name,
    required this.port,
    required this.baudRate,
  });

  factory Indicator.fromJson(Map<String, dynamic> json) {
    return Indicator(
      indicatorId: json['indicatorId'] as String,
      name: json['name'] as String,
      port: json['port'] as String,
      baudRate: json['baudRate'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'indicatorId': indicatorId,
      'name': name,
      'port': port,
      'baudRate': baudRate,
    };
  }
}
