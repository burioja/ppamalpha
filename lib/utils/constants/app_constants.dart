// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'PPAM Alpha';
  static const String appVersion = '1.0.0';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;
  static const double defaultBorderRadius = 8.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Network
  static const int defaultTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;
}