class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'TRADEWORKS_API_BASE_URL',
    defaultValue: '',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'TRADEWORKS_GOOGLE_WEB_CLIENT_ID',
    // The public web OAuth client currently used by the website's Supabase
    // Google provider. Native sign-in requests an ID token for this audience.
    defaultValue:
        '71668222585-rqkkka95up18boigb4gdth4mi9bindce.apps.googleusercontent.com',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'TRADEWORKS_GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
  static const String rewardsUrl = String.fromEnvironment(
    'TRADEWORKS_REWARDS_API_URL',
    defaultValue:
        'https://tradeworks-api-7mobhz4bsq-ue.a.run.app/homeowner/rewards',
  );
  static const String _defaultHostedBaseUrl =
      'https://tradeworks-api-7mobhz4bsq-ue.a.run.app/';

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
