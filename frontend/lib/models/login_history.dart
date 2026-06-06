class LoginHistory {
  final int id;
  final String ipAddress;
  final String? userAgent;
  final String? deviceName;
  final String loginStatus;
  final String riskLevel;
  final String? reason;
  final String loginTime;

  LoginHistory({
    required this.id,
    required this.ipAddress,
    required this.userAgent,
    required this.deviceName,
    required this.loginStatus,
    required this.riskLevel,
    required this.reason,
    required this.loginTime,
  });

  factory LoginHistory.fromJson(Map<String, dynamic> json) {
    return LoginHistory(
      id: json['id'] as int,
      ipAddress: json['ip_address']?.toString() ?? '',
      userAgent: json['user_agent']?.toString(),
      deviceName: json['device_name']?.toString(),
      loginStatus: json['login_status']?.toString() ?? '',
      riskLevel: json['risk_level']?.toString() ?? 'LOW',
      reason: json['reason']?.toString(),
      loginTime: json['login_time']?.toString() ?? '',
    );
  }
}
