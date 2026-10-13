import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_theme.dart';
import 'widgets/uls_logo.dart';

import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/password_setup_screen.dart';
import 'screens/instructor/instructor_dashboard.dart';
import 'screens/student/student_dashboard.dart';

import 'screens/web/admin/admin_web_dashboard.dart';
import 'screens/web/instructor/instructor_web_dashboard.dart';
import 'screens/web/web_access_denied_screen.dart';
import 'screens/web/web_login_screen.dart';

import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gcpgxrixfslrrooogvef.supabase.co',
    publishableKey: 'sb_publishable_lWqAxL5BEYMOztIuBF5ZTQ_7JlMU5US',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSCAS - Smart Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
      routes: {
        // Mobile
        '/login': (context) => const LoginScreen(),
        '/set-password': (context) => const PasswordSetupScreen(),
        '/student-dashboard': (context) => const StudentDashboard(),
        '/instructor-dashboard': (context) => const InstructorDashboard(),
        '/admin-dashboard': (context) => const AdminDashboard(),

        // Web
        '/web-login': (context) => const WebLoginScreen(),
        '/web-access-denied': (context) => const WebAccessDeniedScreen(),
        '/web-instructor-dashboard': (context) =>
            const InstructorWebDashboard(),
        '/web-admin-dashboard': (context) => const AdminWebDashboard(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 700));

    final authenticated = await _authService.isAuthenticated();

    if (!mounted) {
      return;
    }

    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser?.userMetadata?['onboarding_required'] == true) {
      Navigator.pushReplacementNamed(context, '/set-password');
      return;
    }

    if (!authenticated) {
      _goToLogin();
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    String? role = prefs.getString('user_role');

    if (role == null || role.isEmpty) {
      try {
        final user = await _authService.getCurrentUser();

        role = user?['role']?.toString().trim().toLowerCase();

        if (role != null && role.isNotEmpty) {
          await prefs.setString('user_role', role);
        }
      } catch (_) {
        await _authService.logout();

        if (mounted) {
          _goToLogin();
        }

        return;
      }
    }

    if (!mounted) {
      return;
    }

    _routeByRole(role);
  }

  void _goToLogin() {
    if (kIsWeb) {
      Navigator.pushReplacementNamed(context, '/web-login');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _routeByRole(String? role) {
    if (kIsWeb) {
      switch (role) {
        case 'instructor':
          Navigator.pushReplacementNamed(context, '/web-instructor-dashboard');
          break;

        case 'admin':
          Navigator.pushReplacementNamed(context, '/web-admin-dashboard');
          break;

        case 'student':
          Navigator.pushReplacementNamed(context, '/web-access-denied');
          break;

        default:
          _logoutAndReturnToLogin();
      }

      return;
    }

    switch (role) {
      case 'student':
        Navigator.pushReplacementNamed(context, '/student-dashboard');
        break;

      case 'instructor':
        Navigator.pushReplacementNamed(context, '/instructor-dashboard');
        break;

      case 'admin':
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
        break;

      default:
        _logoutAndReturnToLogin();
    }
  }

  Future<void> _logoutAndReturnToLogin() async {
    await _authService.logout();

    if (!mounted) {
      return;
    }

    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const UlsLogo(size: 92),
            const SizedBox(height: 20),
            Text(
              'MSCAS',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mobile Smart Classroom\nAttendance System',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
