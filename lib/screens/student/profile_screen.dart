import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/face_recognition_service.dart';
import 'face_registration.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final FaceRecognitionService _faceService = FaceRecognitionService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _faceRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = AuthService();
    final userData = await authService.getCurrentUser();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    bool registered = false;

    if (uid.isNotEmpty) {
      registered = await _faceService.hasRegisteredFace(uid);
    }

    if (!mounted) return;

    setState(() {
      _userData = userData;
      _faceRegistered = registered;
      _isLoading = false;
    });
  }

  String get _fullName {
    final first = _userData?['first_name']?.toString() ?? '';
    final last = _userData?['last_name']?.toString() ?? '';

    final result = '$first $last'.trim();

    return result.isEmpty ? 'Student' : result;
  }

  Future<void> _registerFace() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FaceRegistrationScreen()),
    );

    if (result == true) {
      await _loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final studentNumber = _userData?['student_number']?.toString() ?? 'N/A';

    final course = _userData?['course']?.toString() ?? 'N/A';

    final email = _userData?['email']?.toString() ?? 'N/A';

    final year = _userData?['year_level']?.toString() ?? 'N/A';

    return RefreshIndicator(
      onRefresh: _loadUser,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _ProfileHeader(
            fullName: _fullName,
            studentNumber: studentNumber,
            course: course,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Information',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 14),
                  width: 36,
                  height: 2,
                  color: AppTheme.primary,
                ),
                _InfoCard(
                  icon: Icons.mail_outline,
                  label: 'Email Address',
                  value: email,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.badge_outlined,
                  label: 'Student ID',
                  value: studentNumber,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.school_outlined,
                  label: 'Course',
                  value: course,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.layers_outlined,
                  label: 'Year Level',
                  value: year,
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _faceRegistered
                                    ? 'Face Registration'
                                    : 'Face Registration',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              _faceRegistered
                                  ? Icons.verified_rounded
                                  : Icons.face_retouching_natural_rounded,
                              color: _faceRegistered
                                  ? Colors.green
                                  : AppTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _faceRegistered
                              ? 'Your face template is ready for normal and shared-device attendance recognition.'
                              : 'Register your face before using face attendance.',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            height: 1.35,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _registerFace,
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: Text(
                            _faceRegistered
                                ? 'Re-register Face'
                                : 'Register Face',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String fullName;
  final String studentNumber;
  final String course;

  const _ProfileHeader({
    required this.fullName,
    required this.studentNumber,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF274CA8), Color(0xFF3C7BF4)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 106,
                height: 106,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 62,
                  color: Color(0xFFB7C2DE),
                ),
              ),
              Positioned(
                right: -1,
                bottom: 4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: $studentNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            course,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
