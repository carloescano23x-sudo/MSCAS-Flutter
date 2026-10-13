import 'dart:math';

import '../../../services/supabase_firestore_compat.dart';
import '../../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/bulk_csv_service.dart';
import '../../../services/enrollment_notification_service.dart';
import '../../../services/report_print_service.dart';
import '../../../services/session_time_service.dart';
import '../../../widgets/uls_logo.dart';

class InstructorWebDashboard extends StatefulWidget {
  const InstructorWebDashboard({super.key});

  @override
  State<InstructorWebDashboard> createState() => _InstructorWebDashboardState();
}

class _InstructorWebDashboardState extends State<InstructorWebDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _department = '';

  String _reportClassId = 'all';
  DateTime? _reportDate;
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;

  @override
  void initState() {
    super.initState();
    _loadInstructorProfile();
  }

  String? get _instructorId => _auth.currentUser?.uid;

  String get _fullName {
    final value = '$_firstName $_lastName'.trim();
    return value.isEmpty ? 'Instructor' : value;
  }

  Future<void> _loadInstructorProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        await _goToLogin();
        return;
      }

      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        await _authService.logout();
        await _goToLogin();
        return;
      }

      final role = data['role']?.toString().trim().toLowerCase();
      if (role != 'instructor') {
        await _authService.logout();
        await _goToLogin();
        return;
      }

      if (!mounted) return;

      setState(() {
        _firstName = data['first_name']?.toString() ?? '';
        _lastName = data['last_name']?.toString() ?? '';
        _email = data['email']?.toString() ?? user.email ?? '';
        _department = data['department']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load instructor profile: $e');
    }
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/web-login', (route) => false);
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    await _authService.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/web-login', (route) => false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCurrentPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 270,
      color: const Color(0xFF21449C),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Row(
                children: [
                  UlsLogo(size: 38),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MSCAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Instructor Portal',
                        style: TextStyle(
                          color: Color(0xFFBCCCDC),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF3E62AD), height: 1),
            const SizedBox(height: 16),
            _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
            _navItem(1, Icons.class_rounded, 'Classes'),
            _navItem(2, Icons.people_alt_rounded, 'Class Students'),
            _navItem(3, Icons.play_circle_fill_rounded, 'Attendance Sessions'),
            _navItem(4, Icons.pin_rounded, 'PIN Fallback'),
            _navItem(5, Icons.fact_check_rounded, 'Attendance Records'),
            _navItem(6, Icons.bar_chart_rounded, 'Reports'),
            _navItem(7, Icons.person_rounded, 'Profile'),
            const Spacer(),
            const Divider(color: Color(0xFF3E62AD), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingOut ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF829AB1)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(_isLoggingOut ? 'Signing out...' : 'Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String title) {
    final selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFF2F64D6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: selected ? Colors.white : const Color(0xFFBCCCDC),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFBCCCDC),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            _pageTitle,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Color(0xFF21449C),
            ),
          ),
          const Spacer(),
          CircleAvatar(
            backgroundColor: const Color(0xFFE3F2FD),
            child: Text(
              _firstName.isEmpty ? 'I' : _firstName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF21449C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                _department.isEmpty ? 'Instructor' : _department,
                style: const TextStyle(fontSize: 12, color: Color(0xFF627D98)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _pageTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Classes';
      case 2:
        return 'Class Students';
      case 3:
        return 'Attendance Sessions';
      case 4:
        return 'PIN Fallback';
      case 5:
        return 'Attendance Records';
      case 6:
        return 'Reports';
      case 7:
        return 'Profile';
      default:
        return 'MSCAS';
    }
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildMyClassesPage();
      case 2:
        return _buildClassStudentsPage();
      case 3:
        return _buildAttendanceSessionsPage();
      case 4:
        return _buildPinFallbackPage();
      case 5:
        return _buildAttendanceRecordsPage();
      case 6:
        return _buildReportsPage();
      case 7:
        return _buildProfilePage();
      default:
        return _buildDashboard();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myClassesStream() {
    final uid = _instructorId;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('classes')
        .where('instructor_id', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myAttendanceStream() {
    final uid = _instructorId;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('attendance')
        .where('instructor_id', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _mySessionsStream() {
    final uid = _instructorId;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('attendance_sessions')
        .where('instructor_id', isEqualTo: uid)
        .snapshots();
  }

  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myClassesStream(),
      builder: (context, classSnapshot) {
        final classes = classSnapshot.data?.docs ?? [];
        final classIds = classes.map((doc) => doc.id).toSet();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('enrollments').snapshots(),
          builder: (context, enrollmentSnapshot) {
            final enrollments = enrollmentSnapshot.data?.docs ?? [];

            final myEnrollments = enrollments.where((document) {
              final classId = document.data()['class_id']?.toString() ?? '';
              return classIds.contains(classId);
            }).toList();

            final uniqueStudentIds = myEnrollments
                .map(
                  (document) => document.data()['student_id']?.toString() ?? '',
                )
                .where((value) => value.isNotEmpty)
                .toSet();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _myAttendanceStream(),
              builder: (context, attendanceSnapshot) {
                final attendance = attendanceSnapshot.data?.docs ?? [];
                final now = DateTime.now();

                int presentToday = 0;
                int lateToday = 0;
                int absentToday = 0;

                for (final document in attendance) {
                  final data = document.data();
                  final timestamp = data['timestamp'];
                  if (timestamp is! Timestamp) continue;

                  final date = timestamp.toDate();
                  final isToday =
                      date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;

                  if (!isToday) continue;

                  final status = data['status']?.toString().toLowerCase();

                  if (status == 'present') {
                    presentToday++;
                  } else if (status == 'late') {
                    lateToday++;
                  } else if (status == 'absent') {
                    absentToday++;
                  }
                }

                final todayClasses = classes.where((document) {
                  final day = document.data()['schedule_day']?.toString() ?? '';
                  return _isToday(day);
                }).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $_fullName',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF21449C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your classes, students and attendance overview.',
                        style: TextStyle(color: Color(0xFF627D98)),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _InstructorStatCard(
                            icon: Icons.class_rounded,
                            title: 'Assigned Classes',
                            value: classes.length.toString(),
                          ),
                          _InstructorStatCard(
                            icon: Icons.today_rounded,
                            title: "Today's Classes",
                            value: todayClasses.toString(),
                          ),
                          _InstructorStatCard(
                            icon: Icons.people_alt_rounded,
                            title: 'Students',
                            value: uniqueStudentIds.length.toString(),
                          ),
                          _InstructorStatCard(
                            icon: Icons.check_circle_rounded,
                            title: 'Present Today',
                            value: presentToday.toString(),
                          ),
                          _InstructorStatCard(
                            icon: Icons.schedule_rounded,
                            title: 'Late Today',
                            value: lateToday.toString(),
                          ),
                          _InstructorStatCard(
                            icon: Icons.cancel_rounded,
                            title: 'Absent Today',
                            value: absentToday.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Instructor Web Portal',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Signed in as $_email. Classes assigned to your Supabase user ID are loaded automatically.',
                                style: const TextStyle(
                                  color: Color(0xFF627D98),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  bool _isToday(String day) {
    final normalized = day.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    const names = <int, String>{
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
    };

    return names[DateTime.now().weekday] == normalized;
  }

  Widget _buildMyClassesPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myClassesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage(
            'Unable to load assigned classes: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final classes = snapshot.data!.docs.toList();
        classes.sort((a, b) {
          final aCode = a.data()['subject_code']?.toString() ?? '';
          final bCode = b.data()['subject_code']?.toString() ?? '';
          return aCode.compareTo(bCode);
        });

        if (classes.isEmpty) {
          return _emptyPage(
            icon: Icons.class_rounded,
            title: 'No Assigned Classes',
            description:
                'An administrator has not assigned any classes to this instructor account yet.',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My Assigned Classes',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF21449C)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _bulkUploadInstructorClasses,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Bulk Upload Classes'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Classes assigned to your instructor account by the MSCAS administrator.',
                style: TextStyle(color: Color(0xFF627D98)),
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width >= 1100
                      ? (width - 36) / 3
                      : width >= 700
                      ? (width - 18) / 2
                      : width;

                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: classes.map((document) {
                      return SizedBox(
                        width: cardWidth,
                        child: _classCard(document.id, document.data()),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _classCard(String classId, Map<String, dynamic> data) {
    final active = data['active'] is bool ? data['active'] as bool : true;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF21449C),
                  ),
                ),
                const Spacer(),
                _statusChip(active),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              data['subject_code']?.toString() ?? '',
              style: const TextStyle(
                color: Color(0xFF21449C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data['subject_name']?.toString() ?? 'Unnamed Subject',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF21449C),
              ),
            ),
            const SizedBox(height: 14),
            _detailLine(
              Icons.groups_rounded,
              'Section',
              data['section']?.toString() ?? '-',
            ),
            _detailLine(
              Icons.room_rounded,
              'Room',
              data['room']?.toString() ?? '-',
            ),
            _detailLine(
              Icons.calendar_today_rounded,
              'Day',
              data['schedule_day']?.toString() ?? '-',
            ),
            _detailLine(
              Icons.schedule_rounded,
              'Time',
              '${data['start_time'] ?? '-'} - ${data['end_time'] ?? '-'}',
            ),
            _detailLine(
              Icons.school_rounded,
              'Semester',
              data['semester']?.toString() ?? '-',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showClassStudentsDialog(
                        classId: classId,
                        classData: data,
                      );
                    },
                    icon: const Icon(Icons.people_alt_rounded),
                    label: const Text('Students'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: active
                        ? () {
                            _showCreateSessionDialog(
                              classId: classId,
                              classData: data,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Session'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF829AB1)),
          const SizedBox(width: 9),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF627D98), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassStudentsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myClassesStream(),
      builder: (context, classSnapshot) {
        if (!classSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final classes = classSnapshot.data!.docs;

        if (classes.isEmpty) {
          return _emptyPage(
            icon: Icons.people_alt_rounded,
            title: 'No Class Students',
            description:
                'Students will appear here after an administrator assigns classes and enrolls students.',
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('enrollments').snapshots(),
          builder: (context, enrollmentSnapshot) {
            if (!enrollmentSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final enrollments = enrollmentSnapshot.data!.docs;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Students by Class',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF21449C)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _bulkUploadInstructorEnrollments,
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Bulk Upload Students'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Students enrolled by the administrator in each of your assigned subjects.',
                    style: TextStyle(color: Color(0xFF627D98)),
                  ),
                  const SizedBox(height: 24),
                  ...classes.map((classDocument) {
                    final classData = classDocument.data();

                    final students = enrollments.where((document) {
                      return document.data()['class_id']?.toString() ==
                          classDocument.id;
                    }).toList();

                    students.sort((a, b) {
                      final aName = a.data()['student_name']?.toString() ?? '';
                      final bName = b.data()['student_name']?.toString() ?? '';
                      return aName.compareTo(bName);
                    });

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 18),
                      child: ExpansionTile(
                        initiallyExpanded: classes.length == 1,
                        title: Text(
                          '${classData['subject_code'] ?? ''} - ${classData['subject_name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${classData['section'] ?? ''} • ${students.length} student${students.length == 1 ? '' : 's'}',
                        ),
                        children: [
                          if (students.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No students are enrolled in this class yet.',
                                style: TextStyle(color: Color(0xFF627D98)),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Student')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Student ID')),
                                ],
                                rows: students.map((document) {
                                  final data = document.data();

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          data['student_name']?.toString() ??
                                              '',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['student_email']?.toString() ??
                                              '',
                                        ),
                                      ),
                                      DataCell(
                                        FutureBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          future: _firestore
                                              .collection('users')
                                              .doc(
                                                data['student_id']
                                                        ?.toString() ??
                                                    '',
                                              )
                                              .get(),
                                          builder: (context, snapshot) {
                                            final studentData = snapshot.data
                                                ?.data();

                                            return Text(
                                              studentData?['student_number']
                                                      ?.toString() ??
                                                  '-',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showClassStudentsDialog({
    required String classId,
    required Map<String, dynamic> classData,
  }) async {
    final snapshot = await _firestore
        .collection('enrollments')
        .where('class_id', isEqualTo: classId)
        .get();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${classData['subject_code'] ?? ''} Students'),
          content: SizedBox(
            width: 650,
            child: snapshot.docs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No students are enrolled in this class yet.'),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: snapshot.docs.map((document) {
                        final data = document.data();

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_rounded),
                          ),
                          title: Text(
                            data['student_name']?.toString() ?? 'Student',
                          ),
                          subtitle: Text(
                            data['student_email']?.toString() ?? '',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  Future<bool> _confirmInstructorBulk({required String title, required String fileName, required int validRows, required List<String> errors, required String template}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('File: $fileName'),
              const SizedBox(height: 8),
              Text('$validRows valid row${validRows == 1 ? '' : 's'} ready to import.'),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...errors.take(12).map((error) => Text('• $error')),
                if (errors.length > 12) Text('• ...and ${errors.length - 12} more.'),
              ],
              const SizedBox(height: 16),
              const Text('CSV format', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SelectableText(template, style: const TextStyle(fontFamily: 'monospace')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: validRows > 0 && errors.isEmpty ? () => Navigator.pop(dialogContext, true) : null, child: const Text('Import')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _bulkUploadInstructorClasses() async {
    const template = 'subject_code,subject_name,section,classroom_name,schedule_day,start_time,end_time,semester\nIT101,Sample Subject,4A,Lab 1,Monday,08:00,09:30,1st Semester';
    final instructorId = _instructorId;
    if (instructorId == null) return;
    try {
      final picked = await BulkCsvService.pickCsv();
      if (picked == null) return;
      final classrooms = (await _firestore.collection('classrooms').get()).docs;
      final errors = <String>[];
      final valid = <Map<String, dynamic>>[];
      for (var i = 0; i < picked.rows.length; i++) {
        final row = picked.rows[i];
        final line = i + 2;
        final code = row['subject_code'] ?? '';
        final name = row['subject_name'] ?? '';
        final roomName = row['classroom_name'] ?? '';
        final rooms = classrooms.where((doc) => (doc.data()['name']?.toString() ?? '').toLowerCase() == roomName.toLowerCase() && doc.data()['active'] != false).toList();
        if (code.isEmpty || name.isEmpty || rooms.length != 1) {
          errors.add('Line $line: subject code/name are required and classroom must match one active classroom.');
          continue;
        }
        final room = rooms.first;
        valid.add({
          'subject_code': code, 'subject_name': name, 'section': row['section'] ?? '',
          'classroom_id': room.id, 'classroom_name': roomName, 'room': roomName,
          'schedule_day': row['schedule_day'] ?? '', 'start_time': row['start_time'] ?? '', 'end_time': row['end_time'] ?? '',
          'semester': row['semester'] ?? '', 'instructor_id': instructorId, 'instructor_name': _fullName,
          'active': true, 'created_at': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      if (!await _confirmInstructorBulk(title: 'Bulk Upload Classes', fileName: picked.fileName, validRows: valid.length, errors: errors, template: template)) return;
      final batch = _firestore.batch();
      for (final data in valid) { batch.set(_firestore.collection('classes').doc(), data); }
      await batch.commit();
      _showMessage('${valid.length} class${valid.length == 1 ? '' : 'es'} imported and assigned to you.');
    } catch (error) { _showMessage('Unable to bulk upload classes: $error'); }
  }

  Future<void> _bulkUploadInstructorEnrollments() async {
    const template = 'student_email,subject_code,section\nstudent@example.edu,IT101,4A';
    final instructorId = _instructorId;
    if (instructorId == null) return;
    try {
      final picked = await BulkCsvService.pickCsv();
      if (picked == null) return;
      final users = (await _firestore.collection('users').get()).docs;
      final classes = (await _firestore.collection('classes').get()).docs.where((doc) => doc.data()['instructor_id']?.toString() == instructorId).toList();
      final existing = (await _firestore.collection('enrollments').get()).docs;
      final errors = <String>[];
      final valid = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (var i = 0; i < picked.rows.length; i++) {
        final row = picked.rows[i];
        final line = i + 2;
        final email = row['student_email'] ?? '';
        final code = row['subject_code'] ?? '';
        final section = row['section'] ?? '';
        final students = users.where((doc) => doc.data()['role'] == 'student' && (doc.data()['email']?.toString() ?? '').toLowerCase() == email.toLowerCase()).toList();
        final matches = classes.where((doc) => (doc.data()['subject_code']?.toString() ?? '').toLowerCase() == code.toLowerCase() && (section.isEmpty || (doc.data()['section']?.toString() ?? '').toLowerCase() == section.toLowerCase())).toList();
        if (students.length != 1 || matches.length != 1) {
          errors.add('Line $line: student and one of your assigned classes must match uniquely.');
          continue;
        }
        final student = students.first;
        final classDoc = matches.first;
        final key = '${student.id}|${classDoc.id}';
        final duplicate = existing.any((doc) => doc.data()['student_id'] == student.id && doc.data()['class_id'] == classDoc.id && doc.data()['active'] != false);
        if (duplicate || !seen.add(key)) {
          errors.add('Line $line: duplicate/already enrolled.');
          continue;
        }
        final sd = student.data(); final cd = classDoc.data();
        valid.add({
          'student_id': student.id, 'student_name': '${sd['first_name'] ?? ''} ${sd['last_name'] ?? ''}'.trim(),
          'student_email': sd['email']?.toString() ?? '', 'student_number': sd['student_number']?.toString() ?? '',
          'course': sd['course']?.toString() ?? '', 'year_level': sd['year_level'], 'class_id': classDoc.id,
          'subject_code': cd['subject_code']?.toString() ?? '', 'subject_name': cd['subject_name']?.toString() ?? '',
          'section': cd['section']?.toString() ?? '', 'instructor_id': instructorId, 'instructor_name': _fullName,
          'room': cd['room']?.toString() ?? '', 'schedule_day': cd['schedule_day']?.toString() ?? '',
          'start_time': cd['start_time']?.toString() ?? '', 'end_time': cd['end_time']?.toString() ?? '', 'semester': cd['semester']?.toString() ?? '',
          'active': true, 'created_at': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      if (!await _confirmInstructorBulk(title: 'Bulk Upload Class Students', fileName: picked.fileName, validRows: valid.length, errors: errors, template: template)) return;
      final batch = _firestore.batch();
      for (final data in valid) { batch.set(_firestore.collection('enrollments').doc(), data); }
      await batch.commit();
      await EnrollmentNotificationService.createForEnrollments(valid);
      _showMessage('${valid.length} student enrollment${valid.length == 1 ? '' : 's'} imported. Students will receive an in-app enrollment notification.');
    } catch (error) { _showMessage('Unable to bulk upload class students: $error'); }
  }

  Widget _buildAttendanceSessionsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mySessionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage(
            'Unable to load attendance sessions: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data!.docs.toList();
        sessions.sort((a, b) {
          final aTime = a.data()['created_at'];
          final bTime = b.data()['created_at'];

          final aDate = aTime is Timestamp
              ? aTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = bTime is Timestamp
              ? bTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        return _pageContainer(
          title: 'Attendance Sessions',
          description:
              'Attendance follows the class schedule. Extend only the current session when class runs overtime.',
          actionLabel: 'Start Session',
          actionIcon: Icons.play_arrow_rounded,
          onAction: _showSelectClassForSessionDialog,
          child: sessions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No attendance sessions have been created yet.',
                      style: TextStyle(color: Color(0xFF627D98)),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Section')),
                      DataColumn(label: Text('Started')),
                      DataColumn(label: Text('Ends')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: sessions.map((document) {
                      final data = document.data();
                      final active = data['active'] == true;
                      final open = SessionTimeService.isOpen(data);
                      final expired = SessionTimeService.isExpired(data);
                      final endAt = SessionTimeService.effectiveEnd(data);

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''}',
                            ),
                          ),
                          DataCell(Text(data['section']?.toString() ?? '')),
                          DataCell(Text(_formatTimestamp(data['created_at']))),
                          DataCell(
                            Text(
                              endAt == null
                                  ? '-'
                                  : SessionTimeService.formatClock(endAt),
                            ),
                          ),
                          DataCell(
                            _sessionStatusChip(
                              open,
                              label: expired && active ? 'Time Ended' : null,
                            ),
                          ),
                          DataCell(
                            active
                                ? Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _extendSession(
                                          document.reference,
                                          data,
                                        ),
                                        icon: const Icon(
                                          Icons.more_time_rounded,
                                        ),
                                        label: const Text('Extend'),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: () async {
                                          await document.reference.update({
                                            'active': false,
                                            'closed_at':
                                                FieldValue.serverTimestamp(),
                                            'close_reason': 'manual',
                                          });
                                          _showMessage(
                                            'Attendance session closed.',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.stop_circle_rounded,
                                        ),
                                        label: const Text('Close'),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Closed',
                                    style: TextStyle(color: Color(0xFF627D98)),
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _showSelectClassForSessionDialog() async {
    final uid = _instructorId;
    if (uid == null) return;

    final snapshot = await _firestore
        .collection('classes')
        .where('instructor_id', isEqualTo: uid)
        .get();

    final classes = snapshot.docs.where((document) {
      final active = document.data()['active'];
      return active is! bool || active;
    }).toList();

    if (!mounted) return;

    if (classes.isEmpty) {
      _showMessage('You do not have an active assigned class.');
      return;
    }

    String? selectedClassId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Start Attendance Session'),
              content: SizedBox(
                width: 500,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: classes.map((document) {
                    final data = document.data();

                    return DropdownMenuItem(
                      value: document.id,
                      child: Text(
                        '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''} (${data['section'] ?? ''})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedClassId = value);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedClassId == null) {
                      _showMessage('Select a class.');
                      return;
                    }

                    final selected = classes.firstWhere(
                      (document) => document.id == selectedClassId,
                    );

                    await _createAttendanceSession(
                      classId: selected.id,
                      classData: selected.data(),
                    );

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateSessionDialog({
    required String classId,
    required Map<String, dynamic> classData,
  }) async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Attendance Session'),
          content: Text(
            'Open attendance for ${classData['subject_code'] ?? ''} - ${classData['subject_name'] ?? ''}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (shouldStart == true) {
      await _createAttendanceSession(classId: classId, classData: classData);
    }
  }

  Future<void> _createAttendanceSession({
    required String classId,
    required Map<String, dynamic> classData,
  }) async {
    final uid = _instructorId;
    if (uid == null) return;

    final existing = await _firestore
        .collection('attendance_sessions')
        .where('class_id', isEqualTo: classId)
        .where('active', isEqualTo: true)
        .get();

    if (existing.docs.any((doc) => SessionTimeService.isOpen(doc.data()))) {
      _showMessage('This class already has an active attendance session.');
      return;
    }

    final scheduleError = SessionTimeService.validateStart(classData);
    if (scheduleError != null) {
      _showMessage(scheduleError);
      return;
    }
    final timeFields = SessionTimeService.fieldsForNewSession(classData);

    await _firestore.collection('attendance_sessions').add({
      'class_id': classId,
      'subject_code': classData['subject_code'] ?? '',
      'subject_name': classData['subject_name'] ?? '',
      'section': classData['section'] ?? '',
      'room': classData['room'] ?? '',
      'classroom_id': classData['classroom_id'] ?? '',
      'classroom_name': classData['classroom_name'] ?? classData['room'] ?? '',
      'instructor_id': uid,
      'instructor_name': _fullName,
      'active': true,
      ...timeFields,
      'created_at': FieldValue.serverTimestamp(),
      'closed_at': null,
    });

    _showMessage('Attendance session started.');
  }

  Future<void> _extendSession(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Extend Attendance'),
        children: [5, 10, 15, 30]
            .map(
              (m) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('+$m minutes'),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (minutes == null) return;
    final newEnd = SessionTimeService.extend(data, minutes);
    await reference.update({
      'effective_end_at': Timestamp.fromDate(newEnd),
      'extended': true,
      'extension_minutes': FieldValue.increment(minutes),
      'last_extended_at': FieldValue.serverTimestamp(),
    });
    _showMessage(
      'Attendance extended until ${SessionTimeService.formatClock(newEnd)}.',
    );
  }

  Widget _buildPinFallbackPage() {
    final uid = _instructorId;

    if (uid == null) {
      return _emptyPage(
        icon: Icons.pin_rounded,
        title: 'PIN Fallback',
        description: 'Instructor session not available.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('pin_sessions')
          .where('instructor_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage('Unable to load PIN sessions: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data!.docs.toList();

        sessions.sort((a, b) {
          final aTime = a.data()['created_at'];
          final bTime = b.data()['created_at'];

          final aDate = aTime is Timestamp
              ? aTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = bTime is Timestamp
              ? bTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        return _pageContainer(
          title: 'PIN Fallback',
          description:
              'Generate a temporary attendance PIN when facial verification cannot be completed.',
          actionLabel: 'Generate PIN',
          actionIcon: Icons.pin_rounded,
          onAction: _showGeneratePinDialog,
          child: sessions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No PIN sessions have been generated.',
                      style: TextStyle(color: Color(0xFF627D98)),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: sessions.map((document) {
                    final data = document.data();
                    final active = _isPinActive(data);

                    return SizedBox(
                      width: 320,
                      child: Card(
                        elevation: 0,
                        color: active ? const Color(0xFFF3F8FF) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${data['subject_code'] ?? ''} ${data['section'] ?? ''}'
                                          .trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _sessionStatusChip(active),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Attendance PIN',
                                style: TextStyle(color: Color(0xFF627D98)),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                data['pin']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 34,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF21449C),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Expires: ${_formatTimestamp(data['expires_at'])}',
                                style: const TextStyle(
                                  color: Color(0xFF627D98),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (active)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await document.reference.update({
                                      'active': false,
                                      'closed_at': FieldValue.serverTimestamp(),
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Disable PIN'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  bool _isPinActive(Map<String, dynamic> data) {
    if (data['active'] != true) return false;

    final expires = data['expires_at'];
    if (expires is! Timestamp) return false;

    return expires.toDate().isAfter(DateTime.now());
  }

  Future<void> _showGeneratePinDialog() async {
    final uid = _instructorId;
    if (uid == null) return;

    final snapshot = await _firestore
        .collection('classes')
        .where('instructor_id', isEqualTo: uid)
        .get();

    final classes = snapshot.docs.where((document) {
      final active = document.data()['active'];
      return active is! bool || active;
    }).toList();

    if (!mounted) return;

    if (classes.isEmpty) {
      _showMessage('You do not have an active assigned class.');
      return;
    }

    String? selectedClassId;
    int durationMinutes = 10;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Generate Attendance PIN'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      items: classes.map((document) {
                        final data = document.data();

                        return DropdownMenuItem(
                          value: document.id,
                          child: Text(
                            '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''} (${data['section'] ?? ''})',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedClassId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: durationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'PIN Validity',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 minutes')),
                        DropdownMenuItem(value: 10, child: Text('10 minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                        DropdownMenuItem(value: 30, child: Text('30 minutes')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => durationMinutes = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedClassId == null) {
                      _showMessage('Select a class.');
                      return;
                    }

                    final selectedClass = classes.firstWhere(
                      (document) => document.id == selectedClassId,
                    );

                    await _generatePin(
                      classId: selectedClass.id,
                      classData: selectedClass.data(),
                      durationMinutes: durationMinutes,
                    );

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generatePin({
    required String classId,
    required Map<String, dynamic> classData,
    required int durationMinutes,
  }) async {
    final uid = _instructorId;
    if (uid == null) return;

    final existing = await _firestore
        .collection('pin_sessions')
        .where('class_id', isEqualTo: classId)
        .where('active', isEqualTo: true)
        .get();

    for (final document in existing.docs) {
      await document.reference.update({
        'active': false,
        'closed_at': FieldValue.serverTimestamp(),
      });
    }

    final pin = (100000 + Random.secure().nextInt(900000)).toString();

    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));

    await _firestore.collection('pin_sessions').add({
      'class_id': classId,
      'subject_code': classData['subject_code'] ?? '',
      'subject_name': classData['subject_name'] ?? '',
      'section': classData['section'] ?? '',
      'instructor_id': uid,
      'instructor_name': _fullName,
      'pin': pin,
      'active': true,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(expiresAt),
      'closed_at': null,
    });

    _showMessage('PIN $pin generated successfully.');
  }

  Widget _buildAttendanceRecordsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myAttendanceStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage(
            'Unable to load attendance records: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data!.docs.toList();

        records.sort((a, b) {
          final aTime = a.data()['timestamp'];
          final bTime = b.data()['timestamp'];

          final aDate = aTime is Timestamp
              ? aTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = bTime is Timestamp
              ? bTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        return _pageContainer(
          title: 'Attendance Records',
          description:
              'Attendance records belonging to classes handled by this instructor.',
          child: records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No attendance records are available yet.',
                      style: TextStyle(color: Color(0xFF627D98)),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Student')),
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Section')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Method')),
                      DataColumn(label: Text('Verified')),
                      DataColumn(label: Text('Date / Time')),
                    ],
                    rows: records.map((document) {
                      final data = document.data();
                      final verified = data['verified'] == true;

                      return DataRow(
                        cells: [
                          DataCell(
                            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              future: _firestore
                                  .collection('users')
                                  .doc(data['student_id']?.toString() ?? '')
                                  .get(),
                              builder: (context, userSnapshot) {
                                final userData = userSnapshot.data?.data();
                                final storedName =
                                    data['student_name']?.toString().trim() ?? '';
                                final profileName =
                                    '${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}'
                                        .trim();
                                final email =
                                    userData?['email']?.toString().trim() ??
                                    data['student_email']?.toString().trim() ??
                                    '';
                                final studentNumber =
                                    userData?['student_number']?.toString().trim() ??
                                    data['student_number']?.toString().trim() ??
                                    '';
                                final displayName = storedName.isNotEmpty
                                    ? storedName
                                    : profileName.isNotEmpty
                                    ? profileName
                                    : email.isNotEmpty
                                    ? email
                                    : studentNumber.isNotEmpty
                                    ? studentNumber
                                    : data['student_id']?.toString() ?? 'Unknown student';
                                return Text(displayName);
                              },
                            ),
                          ),
                          DataCell(
                            Text(
                              data['subject_code']?.toString() ??
                                  data['class_id']?.toString() ??
                                  '',
                            ),
                          ),
                          DataCell(Text(data['section']?.toString() ?? '')),
                          DataCell(
                            _attendanceStatusChip(
                              data['status']?.toString() ?? '',
                            ),
                          ),
                          DataCell(
                            Text(data['verification_method']?.toString() ?? ''),
                          ),
                          DataCell(
                            Icon(
                              verified
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: verified ? Colors.green : Colors.red,
                            ),
                          ),
                          DataCell(Text(_formatTimestamp(data['timestamp']))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildReportsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myAttendanceStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRecords = snapshot.data!.docs;
        final classOptions = <String, String>{};

        for (final document in allRecords) {
          final data = document.data();
          final classId = data['class_id']?.toString() ?? '';
          if (classId.isEmpty) continue;

          final code = data['subject_code']?.toString() ?? '';
          final name = data['subject_name']?.toString() ?? '';
          classOptions[classId] = [
            code,
            name,
          ].where((value) => value.trim().isNotEmpty).join(' - ');
        }

        final records = allRecords.where((document) {
          final data = document.data();

          if (_reportClassId != 'all' &&
              data['class_id']?.toString() != _reportClassId) {
            return false;
          }

          if (_reportDate != null) {
            final target =
                '${_reportDate!.year}-${_reportDate!.month.toString().padLeft(2, '0')}-${_reportDate!.day.toString().padLeft(2, '0')}';
            if (data['date']?.toString() != target) return false;
          }
          if (_reportStartDate != null || _reportEndDate != null) {
            final recordDate = DateTime.tryParse(
              data['date']?.toString() ?? '',
            );
            if (recordDate == null) return false;
            if (_reportStartDate != null &&
                recordDate.isBefore(_reportStartDate!)) {
              return false;
            }
            if (_reportEndDate != null && recordDate.isAfter(_reportEndDate!)) {
              return false;
            }
          }

          return true;
        }).toList();

        final summary = _reportSummary(records);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Instructor Attendance Report',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF21449C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate, preview, and print attendance totals before saving or printing.',
                style: TextStyle(color: Color(0xFF627D98)),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: classOptions.containsKey(_reportClassId)
                          ? _reportClassId
                          : 'all',
                      decoration: const InputDecoration(
                        labelText: 'Class / Subject',
                        prefixIcon: Icon(Icons.class_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Classes'),
                        ),
                        ...classOptions.entries.map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              entry.value.isEmpty ? entry.key : entry.value,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _reportClassId = value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _reportDate ?? DateTime.now(),
                      );

                      if (picked != null && mounted) {
                        setState(() => _reportDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      _reportDate == null
                          ? 'All Dates'
                          : '${_reportDate!.year}-${_reportDate!.month.toString().padLeft(2, '0')}-${_reportDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (_reportDate != null)
                    TextButton(
                      onPressed: () => setState(() => _reportDate = null),
                      child: const Text('Clear Date'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange:
                            _reportStartDate != null && _reportEndDate != null
                            ? DateTimeRange(
                                start: _reportStartDate!,
                                end: _reportEndDate!,
                              )
                            : null,
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _reportDate = null;
                          _reportStartDate = picked.start;
                          _reportEndDate = picked.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                      _reportStartDate == null
                          ? 'Weekly / Term Date Range'
                          : '${_reportStartDate!.year}-${_reportStartDate!.month.toString().padLeft(2, '0')}-${_reportStartDate!.day.toString().padLeft(2, '0')} to ${_reportEndDate!.year}-${_reportEndDate!.month.toString().padLeft(2, '0')}-${_reportEndDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (_reportStartDate != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _reportStartDate = null;
                        _reportEndDate = null;
                      }),
                      child: const Text('Clear Range'),
                    ),
                  FilledButton.icon(
                    onPressed: records.isEmpty
                        ? null
                        : () => _showReportPreview(
                            records,
                            'Instructor Attendance Report',
                          ),
                    icon: const Icon(Icons.preview_rounded),
                    label: const Text('Preview Report'),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  _InstructorStatCard(
                    icon: Icons.list_alt_rounded,
                    title: 'Total Attendance',
                    value: summary['total'].toString(),
                  ),
                  _InstructorStatCard(
                    icon: Icons.check_circle_rounded,
                    title: 'Present',
                    value: summary['present'].toString(),
                  ),
                  _InstructorStatCard(
                    icon: Icons.schedule_rounded,
                    title: 'Late',
                    value: summary['late'].toString(),
                  ),
                  _InstructorStatCard(
                    icon: Icons.cancel_rounded,
                    title: 'Absent',
                    value: summary['absent'].toString(),
                  ),
                  _InstructorStatCard(
                    icon: Icons.percent_rounded,
                    title: 'Attendance Rate',
                    value: '${(summary['rate'] as double).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    records.isEmpty
                        ? 'No attendance records match the selected filters.'
                        : '${records.length} attendance record(s) match the selected filters. Use Preview Report to inspect the printable layout before printing or saving as PDF.',
                    style: const TextStyle(
                      height: 1.5,
                      color: Color(0xFF627D98),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, Object> _reportSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
  ) {
    int present = 0;
    int late = 0;
    int absent = 0;

    for (final document in records) {
      final status = document.data()['status']?.toString().toLowerCase();
      if (status == 'present') {
        present++;
      } else if (status == 'late') {
        late++;
      } else if (status == 'absent') {
        absent++;
      }
    }

    final total = records.length;
    final rate = total == 0 ? 0.0 : ((present + late) / total) * 100;

    return {
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
      'rate': rate,
    };
  }

  Future<void> _showReportPreview(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
    String reportTitle,
  ) async {
    final summary = _reportSummary(records);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reportTitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF21449C),
                              ),
                            ),
                            const Text(
                              'Print Preview',
                              style: TextStyle(color: Color(0xFF627D98)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'UNIVERSITY OF LA SALETTE, INC.\nMSCAS ATTENDANCE REPORT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 20,
                          runSpacing: 10,
                          children: [
                            Text('Total Attendance: ${summary['total']}'),
                            Text('Present: ${summary['present']}'),
                            Text('Late: ${summary['late']}'),
                            Text('Absent: ${summary['absent']}'),
                            Text(
                              'Rate: ${(summary['rate'] as double).toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Student')),
                              DataColumn(label: Text('Student No.')),
                              DataColumn(label: Text('Subject')),
                              DataColumn(label: Text('Section')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Time')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: records.map((document) {
                              final data = document.data();
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      data['student_name']?.toString() ?? '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      data['student_number']?.toString() ?? '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      data['subject_code']?.toString() ?? '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(data['section']?.toString() ?? ''),
                                  ),
                                  DataCell(
                                    Text(data['date']?.toString() ?? ''),
                                  ),
                                  DataCell(
                                    Text(data['time']?.toString() ?? ''),
                                  ),
                                  DataCell(
                                    Text(data['status']?.toString() ?? ''),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close Preview'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () {
                          ReportPrintService.printHtml(
                            _buildReportHtml(records, reportTitle),
                          );
                        },
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print / Save PDF'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildReportHtml(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
    String reportTitle,
  ) {
    String escape(Object? value) => (value?.toString() ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final sorted = records.toList()
      ..sort((a, b) {
        final aName = a.data()['student_name']?.toString().toLowerCase() ?? '';
        final bName = b.data()['student_name']?.toString().toLowerCase() ?? '';
        return aName.compareTo(bName);
      });

    final first = sorted.isEmpty ? <String, dynamic>{} : sorted.first.data();
    final subjectCode = first['subject_code']?.toString() ?? '';
    final subjectName = first['subject_name']?.toString() ?? '';
    final section = first['section']?.toString() ?? '';
    final instructor = first['instructor_name']?.toString() ?? '';
    final dates = sorted
        .map((record) => record.data()['date']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final dateLabel = dates.isEmpty
        ? ''
        : dates.length == 1
        ? dates.first
        : '${dates.first} to ${dates.last}';

    Map<String, dynamic>? recordAt(int index) =>
        index >= 0 && index < sorted.length ? sorted[index].data() : null;

    String studentCells(int index) {
      final data = recordAt(index);
      if (data == null) {
        return '<td class="no">${index + 1}</td><td></td><td></td><td></td><td></td>';
      }
      final status = data['status']?.toString().toUpperCase() ?? '';
      final name = data['student_name']?.toString().trim() ?? '';
      final fallbackName = name.isNotEmpty
          ? name
          : data['student_email']?.toString() ?? data['student_id']?.toString() ?? '';
      return '<td class="no">${index + 1}</td>'
          '<td>${escape(data['student_number'])}</td>'
          '<td>${escape(fallbackName)}</td>'
          '<td class="center">${escape(status)}</td>'
          '<td class="center">${escape(data['time'])}</td>';
    }

    final rows = List.generate(25, (row) {
      final left = studentCells(row);
      final right = studentCells(row + 25);
      return '<tr>$left$right</tr>';
    }).join();

    return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>${escape(reportTitle)}</title>
<style>
@page { size: landscape; margin: 10mm; }
* { box-sizing: border-box; }
body { font-family: Arial, Helvetica, sans-serif; color: #111; margin: 0; font-size: 10px; }
.school { text-align: center; line-height: 1.25; margin-bottom: 8px; }
.school .university { font-size: 13px; font-weight: 700; }
.school .college { font-size: 11px; font-weight: 700; }
.school .sheet { font-size: 11px; font-weight: 700; }
.meta { width: 100%; border-collapse: collapse; margin-bottom: 7px; }
.meta td { border: 0; padding: 2px 5px; }
.meta .label { width: 75px; font-weight: 700; white-space: nowrap; }
.meta .line { border-bottom: 1px solid #111; min-width: 140px; }
.roster { width: 100%; border-collapse: collapse; table-layout: fixed; }
.roster th, .roster td { border: 1px solid #555; padding: 3px 4px; height: 20px; }
.roster th { text-align: center; font-weight: 700; background: #f2f2f2; }
.roster .no { width: 28px; text-align: center; }
.roster th:nth-child(2), .roster th:nth-child(7) { width: 78px; }
.roster th:nth-child(4), .roster th:nth-child(9) { width: 58px; }
.roster th:nth-child(5), .roster th:nth-child(10) { width: 50px; }
.center { text-align: center; }
.footer { margin-top: 10px; width: 100%; border-collapse: collapse; }
.footer td { border: 0; padding: 4px; vertical-align: bottom; }
.signature { border-bottom: 1px solid #111; height: 25px; min-width: 180px; }
.note { margin-top: 8px; font-size: 9px; }
@media print { body { -webkit-print-color-adjust: exact; print-color-adjust: exact; } }
</style>
</head>
<body>
<div class="school">
  <div class="university">UNIVERSITY OF LA SALETTE, INC.</div>
  <div>COLLEGE OF INFORMATION TECHNOLOGY</div>
  <div class="sheet">ATTENDANCE SHEET</div>
</div>
<table class="meta">
<tr>
  <td class="label">Class Code:</td><td class="line">${escape(subjectCode)}</td>
  <td class="label">Section:</td><td class="line">${escape(section)}</td>
  <td class="label">Date:</td><td class="line">${escape(dateLabel)}</td>
</tr>
<tr>
  <td class="label">Description:</td><td class="line" colspan="3">${escape(subjectName)}</td>
  <td class="label">Instructor:</td><td class="line">${escape(instructor)}</td>
</tr>
</table>
<table class="roster">
<thead>
<tr>
  <th>No.</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Time</th>
  <th>No.</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Time</th>
</tr>
</thead>
<tbody>$rows</tbody>
</table>
<table class="footer">
<tr>
  <td>Noted by:</td><td class="signature"></td><td style="width:25px"></td>
  <td>Date:</td><td class="signature"></td>
</tr>
<tr>
  <td></td><td style="text-align:center">Instructor's Signature</td><td></td><td></td><td></td>
</tr>
</table>
<div class="note">Remarks: MSCAS-generated attendance. Status and verification details are retained in the digital attendance record.</div>
</body>
</html>''';
  }


  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instructor Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 28),
                _profileRow('Name', _fullName),
                _profileRow('Email', _email),
                _profileRow('Role', 'Instructor'),
                _profileRow(
                  'Department',
                  _department.isEmpty ? 'Not specified' : _department,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageContainer({
    required String title,
    required String description,
    required Widget child,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF21449C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(color: Color(0xFF627D98)),
                        ),
                      ],
                    ),
                  ),
                  if (onAction != null && actionLabel != null)
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.add_rounded),
                      label: Text(actionLabel),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF627D98),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: active ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sessionStatusChip(bool active, {String? label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? (active ? 'Open' : 'Closed'),
        style: TextStyle(
          color: active ? const Color(0xFF2E7D32) : const Color(0xFF627D98),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _attendanceStatusChip(String status) {
    final normalized = status.trim().toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'present':
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
        break;
      case 'late':
        background = const Color(0xFFFFF8E1);
        foreground = const Color(0xFFF57F17);
        break;
      case 'absent':
        background = const Color(0xFFFFEBEE);
        foreground = const Color(0xFFC62828);
        break;
      default:
        background = const Color(0xFFF1F5F9);
        foreground = const Color(0xFF627D98);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? 'Unknown' : status,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '$hour:$minute $period';
  }

  Widget _emptyPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 76, color: const Color(0xFF829AB1)),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF21449C),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

class _InstructorStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InstructorStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 235,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF21449C)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
