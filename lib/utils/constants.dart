import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'MSCAS';
  static const String appFullName = 'Mobile Smart Classroom Application System';

  static const String roleStudent = 'student';
  static const String roleInstructor = 'instructor';
  static const String roleAdmin = 'admin';

  static const double defaultGeofenceRadiusMeters = 30;
  static const int faceRegistrationSamples = 5;

  static const Duration shortAnimation = Duration(milliseconds: 250);
  static const Duration standardTimeout = Duration(seconds: 30);

  static const Color primaryBlue = Color(0xFF21449C);
}
