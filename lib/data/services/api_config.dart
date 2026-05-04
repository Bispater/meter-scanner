class ApiConfig {
  // TODO: Change to your production URL when deploying
  static const String baseUrl = 'https://scan-service.favric.cl';

  // Development URL (uncomment for local dev)
  // static const String baseUrl = 'http://10.0.2.2:8001'; // Android emulator
  // static const String baseUrl = 'http://localhost:8001'; // iOS simulator

  static const String loginUrl = '$baseUrl/api/auth/login/';
  static const String refreshUrl = '$baseUrl/api/auth/refresh/';
  static const String meUrl = '$baseUrl/api/accounts/users/me/';
  static const String measurementsUrl = '$baseUrl/api/measurements/';
  static const String ocrUrl = '$baseUrl/api/measurements/ocr/';
  static const String notificationsUrl = '$baseUrl/api/notifications/';
}
