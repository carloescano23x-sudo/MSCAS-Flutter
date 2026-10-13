class ApiConfig {
  // https://liking-zone-earthworm.ngrok-free.dev -> http://localhost:8000
  static const String baseUrl = 'https://liking-zone-earthworm.ngrok-free.dev';

  static const int timeoutSeconds = 30;

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String getClasses = '/student/classes';
  static const String markAttendanceFace = '/attendance/face';
  static const String markAttendancePin = '/attendance/pin';
  static const String getAttendanceHistory = '/attendance/history';
}
