/// API endpoint configuration.
///
/// Override at build/run time with dart-define flags, e.g.:
///   flutter run --dart-define=API_BASE_URL=https://magrayorchards.com/api
///   flutter build apk --dart-define=API_BASE_URL=https://magrayorchards.com/api
///
/// The image base URL is derived from [baseUrl] unless API_IMAGE_BASE_URL is
/// provided explicitly.
class ApiConfig {
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const String _imageBaseUrlOverride = String.fromEnvironment('API_IMAGE_BASE_URL');

  static const String _defaultBaseUrl = 'http://localhost:8000/api';
  static const String _defaultImageBaseUrl = 'http://localhost:8000/api/images/';

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _stripTrailingSlash(_baseUrlOverride);
    }
    return _defaultBaseUrl;
  }

  static String get imageBaseUrl {
    if (_imageBaseUrlOverride.isNotEmpty) {
      return _stripTrailingSlash(_imageBaseUrlOverride);
    }
    if (_baseUrlOverride.isNotEmpty) {
      return '${_stripTrailingSlash(_baseUrlOverride)}/images/';
    }
    return _defaultImageBaseUrl;
  }

  static String _stripTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}