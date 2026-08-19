class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'TRADEWORKS_API_BASE_URL',
    defaultValue: 'https://tradeworks-api-71668222585.us-east1.run.app/',
  );
}
