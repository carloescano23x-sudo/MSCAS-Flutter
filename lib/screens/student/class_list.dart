import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../services/attendance_service.dart';
import 'attendance_camera.dart';
import 'attendance_pin.dart';

class ClassList extends StatefulWidget {
  const ClassList({super.key});

  @override
  State<ClassList> createState() => ClassListState();
}

class ClassListState extends State<ClassList> {
  final AttendanceService _attendanceService = AttendanceService();

  List<Class> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final studentId = user?.uid ?? '';

      if (studentId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final classes = await _attendanceService.getStudentClasses(studentId);

      if (!mounted) return;
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'Failed to load enrolled subjects: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  void _markAttendance(Class classObj) {
    if (!classObj.isActive) {
      Fluttertoast.showToast(
        msg: 'This class is currently inactive.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (!classObj.hasActiveSession) {
      Fluttertoast.showToast(
        msg: 'Your instructor has not opened attendance for this class.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${classObj.classCode} Attendance',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  classObj.className,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF0FF),
                    child: Icon(Icons.face_rounded, color: AppTheme.primary),
                  ),
                  title: const Text('Face Recognition'),
                  subtitle: const Text(
                    'Verify your registered face and classroom location.',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceCamera(classObj: classObj),
                      ),
                    );

                    if (result == true) await _loadClasses();
                  },
                ),
                const Divider(),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF0FF),
                    child: Icon(Icons.pin_rounded, color: AppTheme.primary),
                  ),
                  title: const Text('PIN Fallback'),
                  subtitle: const Text(
                    'Use the temporary PIN supplied by the instructor.',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendancePin(classObj: classObj),
                      ),
                    );

                    if (result == true) await _loadClasses();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          if (_classes.isEmpty)
            _buildEmptyState()
          else
            ..._classes.map(_buildClassCard),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF3)),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          const Text(
            'No Enrolled Subjects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Subjects assigned by the administrator will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Class classObj) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _markAttendance(classObj),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classObj.classCode,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            classObj.className,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                            ),
                          ),
                          if (classObj.section.isNotEmpty)
                            Text(
                              classObj.section,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _SessionChip(active: classObj.hasActiveSession),
                  ],
                ),
                const SizedBox(height: 13),
                _infoRow(
                  Icons.person_rounded,
                  classObj.instructorName.isEmpty
                      ? 'Instructor not assigned'
                      : classObj.instructorName,
                ),
                _infoRow(
                  Icons.schedule_rounded,
                  classObj.scheduleText.isEmpty
                      ? 'Schedule not specified'
                      : classObj.scheduleText,
                ),
                _infoRow(
                  Icons.location_on_rounded,
                  classObj.room?.isNotEmpty == true
                      ? classObj.room!
                      : 'Room not specified',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: classObj.hasActiveSession
                        ? () => _markAttendance(classObj)
                        : null,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      classObj.hasActiveSession
                          ? 'Mark Attendance'
                          : 'Attendance Not Open',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF52647F)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final bool active;

  const _SessionChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF7EA) : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Attendance Open' : 'Closed',
        style: TextStyle(
          color: active ? const Color(0xFF2E7D32) : AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
