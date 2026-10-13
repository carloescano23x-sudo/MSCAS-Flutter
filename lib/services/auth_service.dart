import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_service.dart';

class AuthService {
  final FirebaseService _backend = FirebaseService();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _backend.signInWithEmail(
        email: email.trim(),
        password: password,
      );

      final user = response.user;

      if (user == null) {
        return _failure('Login failed. Supabase did not return a user.');
      }

      return await _finishLogin(user);
    } on AuthException catch (e) {
      return _failure(_authMessage(e));
    } catch (e) {
      return _failure('Unexpected login error: $e');
    }
  }

  Future<Map<String, dynamic>> _finishLogin(User user) async {
    final userDoc = await _backend.users.doc(user.id).get();
    final data = userDoc.data();

    if (!userDoc.exists || data == null) {
      await _backend.signOut();

      return _failure(
        'Your Supabase account exists, but your MSCAS profile is missing. '
        'Ask the administrator to create/approve your profile.',
      );
    }

    if (data['active'] == false) {
      await _backend.signOut();

      return _failure(
        'This MSCAS account is inactive. Please contact the administrator.',
      );
    }

    final role = data['role']?.toString().trim().toLowerCase() ?? '';

    if (!{'student', 'instructor', 'admin'}.contains(role)) {
      await _backend.signOut();

      return _failure('Your MSCAS profile has an invalid or missing role.');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('auth_token', user.id);
    await prefs.setString('user_role', role);

    return {
      'success': true,
      'role': role,
      'user': {
        'user_id': user.id,
        'email': user.email ?? '',
        'first_name': data['first_name']?.toString() ?? '',
        'last_name': data['last_name']?.toString() ?? '',
        'role': role,
        'student_number': data['student_number']?.toString() ?? '',
        'course': data['course']?.toString() ?? '',
        'year_level': (data['year_level'] as num?)?.toInt() ?? 1,
      },
    };
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String studentNumber,
    required String course,
    required int yearLevel,
    required String role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      if (!normalizedEmail.endsWith('@uls.edu.ph')) {
        return _failure('Must use a valid ULS email (@uls.edu.ph).');
      }

      final existing = await _backend.users
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return _failure('Email already registered.');
      }

      final response = await _backend.supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'role': role.trim().toLowerCase(),
          'student_number': studentNumber.trim(),
          'course': course.trim(),
          'year_level': yearLevel,
        },
      );

      final user = response.user;

      if (user == null) {
        return _failure('Registration failed. Supabase returned no user.');
      }

      if (response.session != null) {
        await _backend.saveUserProfile(
          uid: user.id,
          email: normalizedEmail,
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          role: role.trim().toLowerCase(),
          studentNumber: studentNumber.trim(),
          course: course.trim(),
          yearLevel: yearLevel,
        );
      }

      await _backend.signOut();

      return {
        'success': true,
        'message': response.session == null
            ? 'Registration successful. Check your email to confirm '
                  'the account before signing in.'
            : 'Registration successful. You can now sign in.',
        'user_id': user.id,
      };
    } on AuthException catch (e) {
      return _failure(_authMessage(e));
    } catch (e) {
      return _failure('Unexpected registration error: $e');
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return _failure('Enter a valid email address.');
    }

    try {
      await _backend.sendPasswordResetEmail(normalizedEmail);

      return {'success': true, 'message': 'Password reset email sent.'};
    } on AuthException catch (e) {
      return _failure(_authMessage(e));
    } catch (e) {
      return _failure('Unable to send password reset email: $e');
    }
  }

  Future<Map<String, dynamic>> signInWithMicrosoft() async {
    try {
      final started = await _backend.supabase.auth.signInWithOAuth(
        OAuthProvider.azure,
        scopes: 'email openid profile',
        redirectTo: kIsWeb ? Uri.base.origin : 'mscas://login-callback/',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!started) {
        return _failure('Unable to start Microsoft sign-in.');
      }

      return {'success': true, 'message': 'Continue sign-in with Microsoft.'};
    } on AuthException catch (e) {
      return _failure(_authMessage(e));
    } catch (e) {
      return _failure('Microsoft sign-in error: $e');
    }
  }

  Future<Map<String, dynamic>> finishMicrosoftLogin() async {
    try {
      final user = _backend.supabase.auth.currentUser;

      if (user == null) {
        return _failure(
          'Microsoft sign-in did not create '
          'a Supabase session.',
        );
      }

      return await _finishLogin(user);
    } on AuthException catch (e) {
      return _failure(_authMessage(e));
    } catch (e) {
      return _failure('Unable to complete Microsoft sign-in: $e');
    }
  }

  Future<void> logout() async {
    await _backend.signOut();

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('auth_token');
    await prefs.remove('user_role');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = _backend.currentUser;

    if (user == null) {
      return null;
    }

    return (await _backend.users.doc(user.id).get()).data();
  }

  Future<bool> isAuthenticated() async {
    final user = _backend.currentUser;
    final prefs = await SharedPreferences.getInstance();

    if (user == null) {
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
      return false;
    }

    final profile = await _backend.users.doc(user.id).get();

    if (!profile.exists) {
      return false;
    }

    final role = profile.data()?['role']?.toString().toLowerCase();

    await prefs.setString('auth_token', user.id);

    if (role != null) {
      await prefs.setString('user_role', role);
    }

    return true;
  }

  Map<String, dynamic> _failure(String message) {
    return {'success': false, 'message': message};
  }

  String _authMessage(AuthException e) {
    final message = e.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }

    if (message.contains('email not confirmed')) {
      return 'Confirm your email before signing in.';
    }

    if (message.contains('already registered')) {
      return 'An account already exists for this email.';
    }

    return 'Supabase Authentication error: '
        '${e.message}';
  }
}
