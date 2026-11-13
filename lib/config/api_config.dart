/// API endpoint configuration.
///
/// Defaults to the production API (https://magrayorchards.com). Override at
/// build/run time with dart-define flags, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
///   flutter build apk --dart-define=API_BASE_URL=http://localhost:8000/api
///
/// The image base URL is derived from [baseUrl] unless API_IMAGE_BASE_URL is
/// provided explicitly.
class ApiConfig {
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const String _imageBaseUrlOverride = String.fromEnvironment('API_IMAGE_BASE_URL');

  static const String _defaultBaseUrl = 'https://magrayorchards.com/api';

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      final stripped = _stripTrailingSlash(_baseUrlOverride);
      return stripped.endsWith('/api') ? stripped : '$stripped/api';
    }
    return _defaultBaseUrl;
  }

  static String get imageBaseUrl {
    if (_imageBaseUrlOverride.isNotEmpty) {
      final stripped = _stripTrailingSlash(_imageBaseUrlOverride);
      return stripped.endsWith('/') ? stripped : '$stripped/';
    }
    return '$baseUrl/images/';
  }

  static String _stripTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}