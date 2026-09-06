class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'TRADEWORKS_API_BASE_URL',
    defaultValue: '',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'TRADEWORKS_GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const String _defaultHostedBaseUrl =
      'https://tradeworks-api-71668222585.us-east1.run.app/';

  static String get baseUrl {
    final configured = _normalize(_configuredBaseUrl);
    if (configured != null) {
      return configured;
    }
    return _defaultHostedBaseUrl;
  }

  static String emptyResponseMessage(String endpoint) {
    return 'Received empty response from server.';
  }

  static String? _normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}
