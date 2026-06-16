class Controller {
  String controllerId;
  String ip;
  int port;
  String serialNumber;

  Controller({
    required this.controllerId,
    required this.ip,
    required this.port,
    required this.serialNumber,
  });

  factory Controller.fromJson(Map<String, dynamic> json) {
    return Controller(
      controllerId: json['controllerId'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      serialNumber: json['serialNumber'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'controllerId': controllerId,
      'ip': ip,
      'port': port,
      'serialNumber': serialNumber,
    };
  }
}
