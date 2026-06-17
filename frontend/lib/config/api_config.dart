class ApiConfig {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  static String get baseUrl {
    final uri = Uri.parse(_baseUrl);
    if (uri.scheme == 'https') {
      return uri.replace(scheme: 'http').toString();
    }
    return _baseUrl;
  }
}
