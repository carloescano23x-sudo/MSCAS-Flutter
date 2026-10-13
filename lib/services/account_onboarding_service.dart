import 'package:supabase_flutter/supabase_flutter.dart';

class AccountOnboardingService {
  AccountOnboardingService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> inviteUser({
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    String studentNumber = '',
    String course = '',
    int yearLevel = 1,
    String employeeNumber = '',
    String department = '',
  }) async {
    final response = await _client.functions.invoke(
      'invite-student',
      body: {
        'email': email.trim().toLowerCase(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role.trim().toLowerCase(),
        'student_number': studentNumber.trim(),
        'course': course.trim(),
        'year_level': yearLevel,
        'employee_number': employeeNumber.trim(),
        'department': department.trim(),
      },
    );

    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'success': false, 'message': 'Unexpected invitation response.'};
  }

  static Future<void> completePasswordSetup(String password) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('The invitation session is missing or expired.');
    }

    await _client.auth.updateUser(
      UserAttributes(
        password: password,
        data: {
          ...(user.userMetadata ?? <String, dynamic>{}),
          'onboarding_required': false,
        },
      ),
    );

    await _client
        .from('users')
        .update({
          'data': {
            'email': user.email ?? '',
            'first_name': user.userMetadata?['first_name'] ?? '',
            'last_name': user.userMetadata?['last_name'] ?? '',
            'role': user.userMetadata?['role'] ?? 'student',
            'student_number': user.userMetadata?['student_number'],
            'course': user.userMetadata?['course'],
            'year_level': user.userMetadata?['year_level'] ?? 1,
            'employee_number': user.userMetadata?['employee_number'],
            'department': user.userMetadata?['department'],
            'active': true,
            'onboarding_pending': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        })
        .eq('id', user.id);
  }
}
