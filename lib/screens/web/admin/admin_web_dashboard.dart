import '../../../services/supabase_firestore_compat.dart';
import '../../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/account_onboarding_service.dart';
import '../../../services/bulk_csv_service.dart';
import '../../../services/enrollment_notification_service.dart';
import '../../../services/report_print_service.dart';
import '../../../widgets/uls_logo.dart';

class AdminWebDashboard extends StatefulWidget {
  const AdminWebDashboard({super.key});

  @override
  State<AdminWebDashboard> createState() => _AdminWebDashboardState();
}

class _AdminWebDashboardState extends State<AdminWebDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  static const List<String> _studentCourses = ['BSIT', 'BSCS', 'BSIS', 'BSEMC'];
  static const List<int> _studentYearLevels = [1, 2, 3, 4];

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _department = '';

  String _reportClassId = 'all';
  DateTime? _reportDate;

  String _attendanceClassFilter = 'all';
  String _attendanceStudentFilter = '';
  String _attendanceMethodFilter = 'all';
  String _attendanceVerifiedFilter = 'all';
  String _attendanceStatusFilter = 'all';
  DateTime? _attendanceDateFilter;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
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

      if (role != 'admin') {
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

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to load administrator profile: $e');
    }
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/web-login', (route) => false);
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

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

  String get _fullName {
    final value = '$_firstName $_lastName'.trim();
    return value.isEmpty ? 'Administrator' : value;
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
                        'Admin Portal',
                        style: TextStyle(
                          color: Color(0xFFB3C4DB),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF344563), height: 1),
            const SizedBox(height: 16),
            _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
            _navItem(1, Icons.people_alt_rounded, 'Users'),
            _navItem(2, Icons.location_on_rounded, 'Classrooms'),
            _navItem(3, Icons.class_rounded, 'Classes'),
            _navItem(4, Icons.group_add_rounded, 'Enrollments'),
            _navItem(5, Icons.fact_check_rounded, 'Attendance'),
            _navItem(6, Icons.bar_chart_rounded, 'Reports'),
            _navItem(7, Icons.person_rounded, 'Profile'),
            const Spacer(),
            const Divider(color: Color(0xFF344563), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingOut ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF8FA6BF)),
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
        selectedTileColor: const Color(0xFF253858),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: selected ? Colors.white : const Color(0xFFB3C4DB),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFB3C4DB),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
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
            backgroundColor: const Color(0xFFE8EAF6),
            child: Text(
              _firstName.isEmpty ? 'A' : _firstName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF2F64D6),
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
              const Text(
                'Administrator',
                style: TextStyle(fontSize: 12, color: Color(0xFF627D98)),
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
        return 'Users';
      case 2:
        return 'Classrooms';
      case 3:
        return 'Classes';
      case 4:
        return 'Enrollments';
      case 5:
        return 'Attendance';
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
        return _buildUsersPage();
      case 2:
        return _buildClassroomsPage();
      case 3:
        return _buildClassesPage();
      case 4:
        return _buildEnrollmentsPage();
      case 5:
        return _buildAttendancePage();
      case 6:
        return _buildReportsPage();
      case 7:
        return _buildProfilePage();
      default:
        return _buildDashboard();
    }
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        int students = 0;
        int instructors = 0;
        int admins = 0;

        if (userSnapshot.hasData) {
          for (final document in userSnapshot.data!.docs) {
            final role = document
                .data()['role']
                ?.toString()
                .trim()
                .toLowerCase();

            if (role == 'student') {
              students++;
            } else if (role == 'instructor') {
              instructors++;
            } else if (role == 'admin') {
              admins++;
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('classes').snapshots(),
          builder: (context, classSnapshot) {
            final classes = classSnapshot.data?.docs.length ?? 0;

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
                    'Manage MSCAS users, classes, enrollments, classrooms, and attendance.',
                    style: TextStyle(color: Color(0xFF627D98)),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      _AdminStatCard(
                        icon: Icons.school_rounded,
                        title: 'Students',
                        value: students.toString(),
                      ),
                      _AdminStatCard(
                        icon: Icons.badge_rounded,
                        title: 'Instructors',
                        value: instructors.toString(),
                      ),
                      _AdminStatCard(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Admins',
                        value: admins.toString(),
                      ),
                      _AdminStatCard(
                        icon: Icons.class_rounded,
                        title: 'Classes',
                        value: classes.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MSCAS Administration',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'The Admin Web Portal and mobile application share the same Supabase Auth and database project. Changes made here are available to the Instructor and Student modules.',
                            style: TextStyle(
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
  }

  // ============================================================
  // USERS
  // ============================================================

  Widget _buildUsersPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage('Unable to load users: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.toList();

        users.sort((a, b) {
          final aName =
              '${a.data()['first_name'] ?? ''} ${a.data()['last_name'] ?? ''}'
                  .trim()
                  .toLowerCase();
          final bName =
              '${b.data()['first_name'] ?? ''} ${b.data()['last_name'] ?? ''}'
                  .trim()
                  .toLowerCase();
          return aName.compareTo(bName);
        });

        return _pageContainer(
          title: 'User Management',
          description:
              'Invite users, manage MSCAS profiles, and track first-password setup.',
          actionLabel: 'Invite User',
          actionIcon: Icons.person_add_rounded,
          onAction: _showAddUserDialog,
          secondaryActionLabel: 'Bulk Upload CSV',
          secondaryActionIcon: Icons.upload_file_rounded,
          onSecondaryAction: _bulkUploadUsers,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('ID Number')),
                DataColumn(label: Text('Course / Department')),
                DataColumn(label: Text('Onboarding')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: users.map((document) {
                final data = document.data();
                final firstName = data['first_name']?.toString() ?? '';
                final lastName = data['last_name']?.toString() ?? '';
                final name = '$firstName $lastName'.trim();
                final role = data['role']?.toString() ?? '';

                final idNumber = role.toLowerCase() == 'student'
                    ? data['student_number']?.toString() ?? ''
                    : data['employee_number']?.toString() ?? '';

                final organization = role.toLowerCase() == 'student'
                    ? data['course']?.toString() ?? ''
                    : data['department']?.toString() ?? '';

                final active = data['active'] is bool
                    ? data['active'] as bool
                    : true;

                return DataRow(
                  cells: [
                    DataCell(Text(name.isEmpty ? 'Not specified' : name)),
                    DataCell(Text(data['email']?.toString() ?? '')),
                    DataCell(_roleChip(role)),
                    DataCell(Text(idNumber.isEmpty ? '-' : idNumber)),
                    DataCell(Text(organization.isEmpty ? '-' : organization)),
                    DataCell(Text(data['onboarding_pending'] == true ? 'Setup Pending' : 'Ready')),
                    DataCell(_statusChip(active)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _showEditUserDialog(document),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: active ? 'Deactivate' : 'Activate',
                            onPressed: () async {
                              await document.reference.update({
                                'active': !active,
                                'updated_at': FieldValue.serverTimestamp(),
                              });
                            },
                            icon: Icon(
                              active
                                  ? Icons.block_rounded
                                  : Icons.check_circle_rounded,
                            ),
                          ),
                        ],
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

  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final idController = TextEditingController();
    final organizationController = TextEditingController();
    final yearController = TextEditingController(text: '1');
    String role = 'student';
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Invite MSCAS User'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'MSCAS will create the authentication account and email a secure first-password setup link. Do not enter or request the user’s Microsoft password.',
                        style: TextStyle(color: Color(0xFF627D98)),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: TextField(controller: firstController, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: lastController, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => role = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: idController,
                        decoration: InputDecoration(labelText: role == 'student' ? 'Student Number' : 'Employee Number', border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      if (role == 'student')
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Course', border: OutlineInputBorder()),
                          items: _studentCourses.map((course) => DropdownMenuItem(value: course, child: Text(course))).toList(),
                          onChanged: (value) => organizationController.text = value ?? '',
                        )
                      else
                        TextField(controller: organizationController, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
                      if (role == 'student') ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: 1,
                          decoration: const InputDecoration(labelText: 'Year Level', border: OutlineInputBorder()),
                          items: _studentYearLevels.map((year) => DropdownMenuItem(value: year, child: Text('$year${year == 1 ? 'st' : year == 2 ? 'nd' : year == 3 ? 'rd' : 'th'} Year'))).toList(),
                          onChanged: (value) => yearController.text = value?.toString() ?? '1',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: sending ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: sending ? null : () async {
                    final email = emailController.text.trim();
                    final first = firstController.text.trim();
                    final last = lastController.text.trim();
                    if (email.isEmpty || first.isEmpty || last.isEmpty) {
                      _showMessage('Email, first name and last name are required.');
                      return;
                    }
                    if (role == 'student' && (organizationController.text.trim().isEmpty || idController.text.trim().isEmpty)) {
                      _showMessage('Student number and course are required.');
                      return;
                    }
                    setDialogState(() => sending = true);
                    try {
                      final result = await AccountOnboardingService.inviteUser(
                        email: email,
                        firstName: first,
                        lastName: last,
                        role: role,
                        studentNumber: role == 'student' ? idController.text.trim() : '',
                        course: role == 'student' ? organizationController.text.trim() : '',
                        yearLevel: int.tryParse(yearController.text.trim()) ?? 1,
                        employeeNumber: role == 'student' ? '' : idController.text.trim(),
                        department: role == 'student' ? '' : organizationController.text.trim(),
                      );
                      if (result['success'] != true) {
                        _showMessage(result['message']?.toString() ?? 'Unable to send invitation.');
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      _showMessage(result['message']?.toString() ?? 'Invitation sent.');
                    } catch (error) {
                      _showMessage('Unable to invite user: $error');
                    } finally {
                      if (dialogContext.mounted) setDialogState(() => sending = false);
                    }
                  },
                  child: Text(sending ? 'Sending...' : 'Send Setup Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditUserDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final emailController = TextEditingController(
      text: data['email']?.toString() ?? '',
    );
    final firstController = TextEditingController(
      text: data['first_name']?.toString() ?? '',
    );
    final lastController = TextEditingController(
      text: data['last_name']?.toString() ?? '',
    );

    String role = data['role']?.toString().toLowerCase() ?? 'student';

    final idController = TextEditingController(
      text: role == 'student'
          ? data['student_number']?.toString() ?? ''
          : data['employee_number']?.toString() ?? '',
    );

    final organizationController = TextEditingController(
      text: role == 'student'
          ? data['course']?.toString() ?? ''
          : data['department']?.toString() ?? '',
    );

    final yearController = TextEditingController(
      text: data['year_level']?.toString() ?? '1',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit User'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SelectableText(
                        'UID: ${document.id}',
                        style: const TextStyle(color: Color(0xFF627D98)),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: firstController,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: lastController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'student',
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: 'instructor',
                            child: Text('Instructor'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            role = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: idController,
                        decoration: InputDecoration(
                          labelText: role == 'student'
                              ? 'Student Number'
                              : 'Employee Number',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (role == 'student')
                        DropdownButtonFormField<String>(
                          initialValue: _studentCourses.contains(organizationController.text.trim())
                              ? organizationController.text.trim()
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Course',
                            border: OutlineInputBorder(),
                          ),
                          items: _studentCourses
                              .map((course) => DropdownMenuItem(value: course, child: Text(course)))
                              .toList(),
                          onChanged: (value) => organizationController.text = value ?? '',
                        )
                      else
                        TextField(
                          controller: organizationController,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      if (role == 'student') ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: _studentYearLevels.contains(int.tryParse(yearController.text.trim()))
                              ? int.tryParse(yearController.text.trim())
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Year Level',
                            border: OutlineInputBorder(),
                          ),
                          items: _studentYearLevels
                              .map((year) => DropdownMenuItem(value: year, child: Text('$year${year == 1 ? 'st' : year == 2 ? 'nd' : year == 3 ? 'rd' : 'th'} Year')))
                              .toList(),
                          onChanged: (value) => yearController.text = value?.toString() ?? '',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final update = <String, dynamic>{
                      'email': emailController.text.trim(),
                      'first_name': firstController.text.trim(),
                      'last_name': lastController.text.trim(),
                      'role': role,
                      'updated_at': FieldValue.serverTimestamp(),
                    };

                    if (role == 'student') {
                      update['student_number'] = idController.text.trim();
                      update['course'] = organizationController.text.trim();
                      update['year_level'] =
                          int.tryParse(yearController.text.trim()) ?? 1;
                      update['employee_number'] = FieldValue.delete();
                      update['department'] = FieldValue.delete();
                    } else {
                      update['employee_number'] = idController.text.trim();
                      update['department'] = organizationController.text.trim();
                      update['student_number'] = FieldValue.delete();
                      update['course'] = FieldValue.delete();
                      update['year_level'] = FieldValue.delete();
                    }

                    await document.reference.update(update);

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    _showMessage('User profile updated.');
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CLASSES
  // ============================================================

  Widget _buildClassesPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('classes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage('Unable to load classes: ${snapshot.error}');
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

        return _pageContainer(
          title: 'Class Management',
          description:
              'Create classes, assign instructors, classroom geofences and schedules.',
          actionLabel: 'Create Class',
          actionIcon: Icons.add_rounded,
          onAction: _showClassDialog,
          secondaryActionLabel: 'Bulk Upload CSV',
          secondaryActionIcon: Icons.upload_file_rounded,
          onSecondaryAction: _bulkUploadClasses,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Section')),
                DataColumn(label: Text('Instructor')),
                DataColumn(label: Text('Room')),
                DataColumn(label: Text('Schedule')),
                DataColumn(label: Text('Semester')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: classes.map((document) {
                final data = document.data();
                final active = data['active'] is bool
                    ? data['active'] as bool
                    : true;
                final code = data['subject_code']?.toString() ?? '';
                final name = data['subject_name']?.toString() ?? '';
                final schedule =
                    '${data['schedule_day'] ?? ''} ${data['start_time'] ?? ''} - ${data['end_time'] ?? ''}'
                        .trim();

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(width: 200, child: Text('$code\n$name'.trim())),
                    ),
                    DataCell(Text(data['section']?.toString() ?? '')),
                    DataCell(
                      Text(
                        data['instructor_name']?.toString() ?? 'Not assigned',
                      ),
                    ),
                    DataCell(Text(data['room']?.toString() ?? '')),
                    DataCell(Text(schedule)),
                    DataCell(Text(data['semester']?.toString() ?? '')),
                    DataCell(_statusChip(active)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () =>
                                _showClassDialog(existing: document),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: active ? 'Deactivate' : 'Activate',
                            onPressed: () async {
                              await document.reference.update({
                                'active': !active,
                                'updated_at': FieldValue.serverTimestamp(),
                              });
                            },
                            icon: Icon(
                              active
                                  ? Icons.block_rounded
                                  : Icons.check_circle_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmDeleteClass(document),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
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

  Future<void> _showClassDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final data = existing?.data() ?? <String, dynamic>{};

    final codeController = TextEditingController(
      text: data['subject_code']?.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: data['subject_name']?.toString() ?? '',
    );
    final sectionController = TextEditingController(
      text: data['section']?.toString() ?? '',
    );
    String? selectedClassroomId = data['classroom_id']?.toString();
    String selectedClassroomName =
        data['classroom_name']?.toString() ?? data['room']?.toString() ?? '';
    final dayController = TextEditingController(
      text: data['schedule_day']?.toString() ?? '',
    );
    final startController = TextEditingController(
      text: data['start_time']?.toString() ?? '',
    );
    final endController = TextEditingController(
      text: data['end_time']?.toString() ?? '',
    );
    final semesterController = TextEditingController(
      text: data['semester']?.toString() ?? '',
    );

    String? selectedInstructorId = data['instructor_id']?.toString();
    String selectedInstructorName = data['instructor_name']?.toString() ?? '';

    final instructorsSnapshot = await _firestore.collection('users').get();
    final instructors = instructorsSnapshot.docs.where((doc) {
      return doc.data()['role']?.toString().toLowerCase() == 'instructor';
    }).toList();

    final classroomsSnapshot = await _firestore.collection('classrooms').get();
    final classrooms = classroomsSnapshot.docs.toList();

    // Compatibility for classes created before classroom_id was added.
    if ((selectedClassroomId == null || selectedClassroomId.isEmpty) &&
        selectedClassroomName.isNotEmpty) {
      final matches = classrooms.where((doc) {
        return doc.data()['name']?.toString().trim().toLowerCase() ==
            selectedClassroomName.trim().toLowerCase();
      });

      if (matches.isNotEmpty) {
        selectedClassroomId = matches.first.id;
        selectedClassroomName =
            matches.first.data()['name']?.toString() ?? selectedClassroomName;
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Create Class' : 'Edit Class'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: codeController,
                              decoration: const InputDecoration(
                                labelText: 'Subject Code',
                                hintText: 'IT 401',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: sectionController,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                hintText: 'BSIT 4A',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedInstructorId,
                        decoration: const InputDecoration(
                          labelText: 'Instructor',
                          border: OutlineInputBorder(),
                        ),
                        items: instructors.map((doc) {
                          final instructorData = doc.data();
                          final fullName =
                              '${instructorData['first_name'] ?? ''} ${instructorData['last_name'] ?? ''}'
                                  .trim();

                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              fullName.isEmpty
                                  ? instructorData['email']?.toString() ??
                                        doc.id
                                  : fullName,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedInstructorId = value;

                            final matching = instructors.where(
                              (doc) => doc.id == value,
                            );

                            if (matching.isEmpty) {
                              selectedInstructorName = '';
                            } else {
                              final instructorData = matching.first.data();
                              selectedInstructorName =
                                  '${instructorData['first_name'] ?? ''} ${instructorData['last_name'] ?? ''}'
                                      .trim();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedClassroomId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Classroom / Geofence',
                          helperText:
                              'The selected classroom location will be used automatically for attendance.',
                          border: OutlineInputBorder(),
                        ),
                        items: classrooms.map((doc) {
                          final classroomData = doc.data();
                          final classroomName =
                              classroomData['name']?.toString() ??
                              'Unnamed classroom';
                          final building =
                              classroomData['building']?.toString() ?? '';
                          final active = classroomData['active'] is bool
                              ? classroomData['active'] as bool
                              : true;

                          final label = building.trim().isEmpty
                              ? classroomName
                              : '$classroomName • $building';

                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              active ? label : '$label (Inactive)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedClassroomId = value;

                            final matches = classrooms.where(
                              (doc) => doc.id == value,
                            );

                            selectedClassroomName = matches.isEmpty
                                ? ''
                                : matches.first.data()['name']?.toString() ??
                                      '';
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: dayController,
                        decoration: const InputDecoration(
                          labelText: 'Schedule Day',
                          hintText: 'Monday',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startController,
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                hintText: '08:00 AM',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endController,
                              decoration: const InputDecoration(
                                labelText: 'End Time',
                                hintText: '09:30 AM',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: semesterController,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          hintText: '1st Semester 2026-2027',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final code = codeController.text.trim();
                    final name = nameController.text.trim();

                    if (code.isEmpty || name.isEmpty) {
                      _showMessage(
                        'Subject code and subject name are required.',
                      );
                      return;
                    }

                    if (selectedClassroomId == null ||
                        selectedClassroomId!.isEmpty) {
                      _showMessage(
                        'Select the classroom/geofence for this subject.',
                      );
                      return;
                    }

                    final selectedClassroomMatches = classrooms.where(
                      (doc) => doc.id == selectedClassroomId,
                    );

                    if (selectedClassroomMatches.isEmpty) {
                      _showMessage(
                        'The selected classroom no longer exists. Choose another classroom.',
                      );
                      return;
                    }

                    final selectedClassroomData = selectedClassroomMatches.first
                        .data();

                    if (selectedClassroomData['active'] == false) {
                      _showMessage(
                        'The selected classroom is inactive. Activate it or choose another classroom.',
                      );
                      return;
                    }

                    selectedClassroomName =
                        selectedClassroomData['name']?.toString() ?? '';

                    final values = <String, dynamic>{
                      'subject_code': code,
                      'subject_name': name,
                      'section': sectionController.text.trim(),
                      'classroom_id': selectedClassroomId,
                      'classroom_name': selectedClassroomName,
                      // Keep room for compatibility with existing Instructor/Student UI.
                      'room': selectedClassroomName,
                      'schedule_day': dayController.text.trim(),
                      'start_time': startController.text.trim(),
                      'end_time': endController.text.trim(),
                      'semester': semesterController.text.trim(),
                      'instructor_id': selectedInstructorId ?? '',
                      'instructor_name': selectedInstructorName,
                      'active': data['active'] is bool ? data['active'] : true,
                      'updated_at': FieldValue.serverTimestamp(),
                    };

                    try {
                      if (existing == null) {
                        values['created_at'] = FieldValue.serverTimestamp();
                        await _firestore.collection('classes').add(values);
                      } else {
                        await _firestore
                            .collection('classes')
                            .doc(existing.id)
                            .update(values);
                      }

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      _showMessage(
                        existing == null ? 'Class created.' : 'Class updated.',
                      );
                    } catch (error) {
                      _showMessage(
                        existing == null
                            ? 'Unable to create class: $error'
                            : 'Unable to save class changes: $error',
                      );
                    }
                  },
                  child: Text(existing == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteClass(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Class'),
          content: const Text(
            'This permanently deletes the class document. Existing enrollments and attendance records are not automatically deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await document.reference.delete();
      _showMessage('Class deleted.');
    }
  }

  // ============================================================
  // ENROLLMENTS - MULTI-CLASS + GROUPED DISPLAY
  // ============================================================

  Widget _buildEnrollmentsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('enrollments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage('Unable to load enrollments: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs;

        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        grouped = {};

        for (final document in documents) {
          final studentId = document.data()['student_id']?.toString() ?? '';
          if (studentId.isEmpty) continue;
          grouped.putIfAbsent(studentId, () => []).add(document);
        }

        final groups = grouped.entries.toList();
        groups.sort((a, b) {
          final aName = a.value.isEmpty
              ? ''
              : a.value.first.data()['student_name']?.toString() ?? '';
          final bName = b.value.isEmpty
              ? ''
              : b.value.first.data()['student_name']?.toString() ?? '';
          return aName.toLowerCase().compareTo(bName.toLowerCase());
        });

        return _pageContainer(
          title: 'Student Enrollments',
          description:
              'Select one student and enroll them in multiple subjects at once. The list below groups all subjects under each student for a cleaner view.',
          actionLabel: 'Enroll Student',
          actionIcon: Icons.group_add_rounded,
          onAction: _showMultiEnrollmentDialog,
          secondaryActionLabel: 'Bulk Upload CSV',
          secondaryActionIcon: Icons.upload_file_rounded,
          onSecondaryAction: _bulkUploadEnrollments,
          child: groups.isEmpty
              ? _emptyState(
                  icon: Icons.group_add_outlined,
                  title: 'No enrollments yet',
                  description:
                      'Enroll a student and select all of their subjects in one action.',
                )
              : Column(
                  children: groups.map((entry) {
                    return _buildStudentEnrollmentCard(
                      studentId: entry.key,
                      enrollmentDocs: entry.value,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Widget _buildStudentEnrollmentCard({
    required String studentId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> enrollmentDocs,
  }) {
    if (enrollmentDocs.isEmpty) {
      return const SizedBox.shrink();
    }

    enrollmentDocs.sort((a, b) {
      final aCode = a.data()['subject_code']?.toString() ?? '';
      final bCode = b.data()['subject_code']?.toString() ?? '';
      return aCode.compareTo(bCode);
    });

    final first = enrollmentDocs.first.data();
    final studentName = first['student_name']?.toString() ?? 'Student';
    final studentEmail = first['student_email']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFE3F2FD),
                child: Text(
                  studentName.isEmpty ? 'S' : studentName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF21449C),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF21449C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      studentEmail,
                      style: const TextStyle(color: Color(0xFF627D98)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${enrollmentDocs.length} enrolled subject${enrollmentDocs.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF829AB1),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showMultiEnrollmentDialog(preselectedStudentId: studentId),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Subjects'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove all enrollments for this student',
                onPressed: () => _confirmRemoveAllStudentEnrollments(
                  studentName: studentName,
                  enrollmentDocs: enrollmentDocs,
                ),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: enrollmentDocs.map((document) {
              final data = document.data();
              final code = data['subject_code']?.toString() ?? '';
              final name = data['subject_name']?.toString() ?? '';
              final section = data['section']?.toString() ?? '';

              return Container(
                constraints: const BoxConstraints(minWidth: 240),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9E2EC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: Color(0xFF2F64D6),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            code.isEmpty ? name : code,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF21449C),
                            ),
                          ),
                          if (name.isNotEmpty && code.isNotEmpty)
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF627D98),
                              ),
                            ),
                          if (section.isNotEmpty)
                            Text(
                              section,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF829AB1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove this subject',
                      onPressed: () => _confirmRemoveEnrollment(document),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showMultiEnrollmentDialog({
    String? preselectedStudentId,
  }) async {
    final usersSnapshot = await _firestore.collection('users').get();
    final classesSnapshot = await _firestore.collection('classes').get();
    final enrollmentsSnapshot = await _firestore
        .collection('enrollments')
        .get();

    final students = usersSnapshot.docs.where((document) {
      final data = document.data();
      final role = data['role']?.toString().trim().toLowerCase();
      final active = data['active'];
      return role == 'student' && (active is! bool || active);
    }).toList();

    final classes = classesSnapshot.docs.where((document) {
      final active = document.data()['active'];
      return active is! bool || active;
    }).toList();

    students.sort((a, b) {
      final aName =
          '${a.data()['first_name'] ?? ''} ${a.data()['last_name'] ?? ''}'
              .trim()
              .toLowerCase();
      final bName =
          '${b.data()['first_name'] ?? ''} ${b.data()['last_name'] ?? ''}'
              .trim()
              .toLowerCase();
      return aName.compareTo(bName);
    });

    classes.sort((a, b) {
      final aCode = a.data()['subject_code']?.toString() ?? '';
      final bCode = b.data()['subject_code']?.toString() ?? '';
      return aCode.compareTo(bCode);
    });

    if (!mounted) return;

    String? selectedStudentId = preselectedStudentId;
    final Set<String> selectedClassIds = <String>{};
    bool saving = false;

    Set<String> existingClassesForStudent(String? studentId) {
      if (studentId == null) return <String>{};

      return enrollmentsSnapshot.docs
          .where((doc) => doc.data()['student_id']?.toString() == studentId)
          .map((doc) => doc.data()['class_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final alreadyEnrolled = existingClassesForStudent(
              selectedStudentId,
            );

            return AlertDialog(
              title: const Text('Enroll Student in Subjects'),
              content: SizedBox(
                width: 650,
                height: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose one student, then select every subject they are enrolled in. You only need to press Enroll once.',
                      style: TextStyle(color: Color(0xFF627D98), height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'Student',
                        border: OutlineInputBorder(),
                      ),
                      items: students.map((document) {
                        final data = document.data();
                        final name =
                            '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                                .trim();
                        final email = data['email']?.toString() ?? '';

                        return DropdownMenuItem(
                          value: document.id,
                          child: Text('$name ($email)'),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(() {
                                selectedStudentId = value;
                                selectedClassIds.clear();
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Select Subjects',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF21449C),
                            ),
                          ),
                        ),
                        if (selectedStudentId != null)
                          TextButton(
                            onPressed: saving
                                ? null
                                : () {
                                    setDialogState(() {
                                      for (final classDoc in classes) {
                                        if (!alreadyEnrolled.contains(
                                          classDoc.id,
                                        )) {
                                          selectedClassIds.add(classDoc.id);
                                        }
                                      }
                                    });
                                  },
                            child: const Text('Select All Available'),
                          ),
                        if (selectedClassIds.isNotEmpty)
                          TextButton(
                            onPressed: saving
                                ? null
                                : () {
                                    setDialogState(() {
                                      selectedClassIds.clear();
                                    });
                                  },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: selectedStudentId == null
                          ? const Center(
                              child: Text(
                                'Select a student first.',
                                style: TextStyle(color: Color(0xFF829AB1)),
                              ),
                            )
                          : classes.isEmpty
                          ? const Center(
                              child: Text('No active classes are available.'),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD9E2EC),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListView.separated(
                                itemCount: classes.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final classDoc = classes[index];
                                  final data = classDoc.data();
                                  final isAlreadyEnrolled = alreadyEnrolled
                                      .contains(classDoc.id);
                                  final checked = selectedClassIds.contains(
                                    classDoc.id,
                                  );

                                  final code =
                                      data['subject_code']?.toString() ?? '';
                                  final name =
                                      data['subject_name']?.toString() ?? '';
                                  final section =
                                      data['section']?.toString() ?? '';
                                  final schedule =
                                      '${data['schedule_day'] ?? ''} ${data['start_time'] ?? ''} - ${data['end_time'] ?? ''}'
                                          .trim();

                                  return CheckboxListTile(
                                    value: isAlreadyEnrolled || checked,
                                    onChanged: isAlreadyEnrolled || saving
                                        ? null
                                        : (value) {
                                            setDialogState(() {
                                              if (value == true) {
                                                selectedClassIds.add(
                                                  classDoc.id,
                                                );
                                              } else {
                                                selectedClassIds.remove(
                                                  classDoc.id,
                                                );
                                              }
                                            });
                                          },
                                    title: Text(
                                      '$code - $name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isAlreadyEnrolled
                                            ? const Color(0xFF829AB1)
                                            : const Color(0xFF21449C),
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (section.isNotEmpty) section,
                                        if (schedule.isNotEmpty) schedule,
                                        if (isAlreadyEnrolled)
                                          'Already enrolled',
                                      ].join(' • '),
                                    ),
                                    secondary: isAlreadyEnrolled
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF2E7D32),
                                          )
                                        : const Icon(Icons.menu_book_rounded),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${selectedClassIds.length} new subject${selectedClassIds.length == 1 ? '' : 's'} selected',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (selectedStudentId == null) {
                            _showMessage('Select a student.');
                            return;
                          }

                          if (selectedClassIds.isEmpty) {
                            _showMessage('Select at least one new subject.');
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final student = students.firstWhere(
                              (document) => document.id == selectedStudentId,
                            );
                            final studentData = student.data();
                            final studentName =
                                '${studentData['first_name'] ?? ''} ${studentData['last_name'] ?? ''}'
                                    .trim();

                            final batch = _firestore.batch();
                            final createdEnrollments = <Map<String, dynamic>>[];
                            int created = 0;

                            for (final classId in selectedClassIds) {
                              if (alreadyEnrolled.contains(classId)) {
                                continue;
                              }

                              final classDoc = classes.firstWhere(
                                (document) => document.id == classId,
                              );
                              final classData = classDoc.data();
                              final enrollmentRef = _firestore
                                  .collection('enrollments')
                                  .doc();

                              final enrollmentData = <String, dynamic>{
                                'student_id': selectedStudentId,
                                'student_name': studentName,
                                'student_email':
                                    studentData['email']?.toString() ?? '',
                                'student_number':
                                    studentData['student_number']?.toString() ??
                                    '',
                                'course':
                                    studentData['course']?.toString() ?? '',
                                'year_level': studentData['year_level'],
                                'class_id': classDoc.id,
                                'subject_code':
                                    classData['subject_code']?.toString() ?? '',
                                'subject_name':
                                    classData['subject_name']?.toString() ?? '',
                                'section':
                                    classData['section']?.toString() ?? '',
                                'instructor_id':
                                    classData['instructor_id']?.toString() ??
                                    '',
                                'instructor_name':
                                    classData['instructor_name']?.toString() ??
                                    '',
                                'room': classData['room']?.toString() ?? '',
                                'schedule_day':
                                    classData['schedule_day']?.toString() ?? '',
                                'start_time':
                                    classData['start_time']?.toString() ?? '',
                                'end_time':
                                    classData['end_time']?.toString() ?? '',
                                'semester':
                                    classData['semester']?.toString() ?? '',
                                'active': true,
                                'created_at': FieldValue.serverTimestamp(),
                                'updated_at': FieldValue.serverTimestamp(),
                              };
                              batch.set(enrollmentRef, enrollmentData);
                              createdEnrollments.add(enrollmentData);

                              created++;
                            }

                            if (created == 0) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                saving = false;
                              });
                              _showMessage('No new enrollments were created.');
                              return;
                            }

                            await batch.commit();
                            await EnrollmentNotificationService.createForEnrollments(
                              createdEnrollments,
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            _showMessage(
                              '$created subject${created == 1 ? '' : 's'} enrolled successfully.',
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              saving = false;
                            });
                            _showMessage('Unable to enroll student: $e');
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(saving ? 'Enrolling...' : 'Enroll Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveEnrollment(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final subject =
        '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''}'.trim();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Subject'),
          content: Text(
            'Remove ${subject.isEmpty ? 'this subject' : subject} from this student?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await document.reference.delete();
      _showMessage('Subject removed from student.');
    }
  }

  Future<void> _confirmRemoveAllStudentEnrollments({
    required String studentName,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> enrollmentDocs,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove All Subjects'),
          content: Text(
            'Remove all ${enrollmentDocs.length} enrolled subjects for $studentName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove All'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final batch = _firestore.batch();
    for (final document in enrollmentDocs) {
      batch.delete(document.reference);
    }
    await batch.commit();
    _showMessage('All subjects removed for $studentName.');
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  Widget _buildAttendancePage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('attendance').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage('Unable to load attendance: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            final userNames = <String, String>{};
            for (final user in userSnapshot.data?.docs ?? []) {
              final data = user.data();
              final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
              userNames[user.id] = name.isNotEmpty ? name : data['email']?.toString() ?? user.id;
            }

            final allRecords = snapshot.data!.docs.toList();
            final classValues = allRecords
                .map((doc) => doc.data()['subject_code']?.toString() ?? doc.data()['class_id']?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()..sort();
            final methodValues = allRecords
                .map((doc) => doc.data()['verification_method']?.toString() ?? doc.data()['method']?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()..sort();
            final statusValues = allRecords
                .map((doc) => doc.data()['status']?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()..sort();

            final search = _attendanceStudentFilter.trim().toLowerCase();
            final records = allRecords.where((document) {
              final data = document.data();
              final className = data['subject_code']?.toString() ?? data['class_id']?.toString() ?? '';
              final method = data['verification_method']?.toString() ?? data['method']?.toString() ?? '';
              final status = data['status']?.toString() ?? '';
              final verified = data['verified'] == true;
              final studentId = data['student_id']?.toString() ?? '';
              final studentName = (data['student_name']?.toString().trim().isNotEmpty == true
                      ? data['student_name'].toString()
                      : userNames[studentId] ?? data['student_email']?.toString() ?? studentId)
                  .toLowerCase();
              final timestamp = data['timestamp'];
              final date = timestamp is Timestamp ? timestamp.toDate() : null;

              if (_attendanceClassFilter != 'all' && className != _attendanceClassFilter) return false;
              if (_attendanceMethodFilter != 'all' && method != _attendanceMethodFilter) return false;
              if (_attendanceStatusFilter != 'all' && status != _attendanceStatusFilter) return false;
              if (_attendanceVerifiedFilter == 'verified' && !verified) return false;
              if (_attendanceVerifiedFilter == 'unverified' && verified) return false;
              if (search.isNotEmpty && !studentName.contains(search)) return false;
              if (_attendanceDateFilter != null) {
                if (date == null || date.year != _attendanceDateFilter!.year || date.month != _attendanceDateFilter!.month || date.day != _attendanceDateFilter!.day) return false;
              }
              return true;
            }).toList();

            records.sort((a, b) {
              final aTime = a.data()['timestamp'];
              final bTime = b.data()['timestamp'];
              final aDate = aTime is Timestamp ? aTime.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = bTime is Timestamp ? bTime.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

            return _pageContainer(
              title: 'Attendance Overview',
              description: 'Filter attendance by class, student, method, verification, status and date.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: 190, child: DropdownButtonFormField<String>(
                        initialValue: classValues.contains(_attendanceClassFilter) ? _attendanceClassFilter : 'all',
                        decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                        items: [const DropdownMenuItem(value: 'all', child: Text('All classes')), ...classValues.map((v) => DropdownMenuItem(value: v, child: Text(v)))],
                        onChanged: (v) => setState(() => _attendanceClassFilter = v ?? 'all'),
                      )),
                      SizedBox(width: 220, child: TextFormField(
                        initialValue: _attendanceStudentFilter,
                        decoration: const InputDecoration(labelText: 'Student name', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => _attendanceStudentFilter = v),
                      )),
                      SizedBox(width: 180, child: DropdownButtonFormField<String>(
                        initialValue: methodValues.contains(_attendanceMethodFilter) ? _attendanceMethodFilter : 'all',
                        decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                        items: [const DropdownMenuItem(value: 'all', child: Text('All methods')), ...methodValues.map((v) => DropdownMenuItem(value: v, child: Text(v)))],
                        onChanged: (v) => setState(() => _attendanceMethodFilter = v ?? 'all'),
                      )),
                      SizedBox(width: 180, child: DropdownButtonFormField<String>(
                        initialValue: _attendanceVerifiedFilter,
                        decoration: const InputDecoration(labelText: 'Verification', border: OutlineInputBorder()),
                        items: const [DropdownMenuItem(value: 'all', child: Text('All')), DropdownMenuItem(value: 'verified', child: Text('Verified')), DropdownMenuItem(value: 'unverified', child: Text('Unverified'))],
                        onChanged: (v) => setState(() => _attendanceVerifiedFilter = v ?? 'all'),
                      )),
                      SizedBox(width: 170, child: DropdownButtonFormField<String>(
                        initialValue: statusValues.contains(_attendanceStatusFilter) ? _attendanceStatusFilter : 'all',
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: [const DropdownMenuItem(value: 'all', child: Text('All statuses')), ...statusValues.map((v) => DropdownMenuItem(value: v, child: Text(v)))],
                        onChanged: (v) => setState(() => _attendanceStatusFilter = v ?? 'all'),
                      )),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(context: context, initialDate: _attendanceDateFilter ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (selected != null) setState(() => _attendanceDateFilter = selected);
                        },
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(_attendanceDateFilter == null ? 'Date' : '${_attendanceDateFilter!.year}-${_attendanceDateFilter!.month.toString().padLeft(2, '0')}-${_attendanceDateFilter!.day.toString().padLeft(2, '0')}'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() { _attendanceClassFilter = 'all'; _attendanceStudentFilter = ''; _attendanceMethodFilter = 'all'; _attendanceVerifiedFilter = 'all'; _attendanceStatusFilter = 'all'; _attendanceDateFilter = null; }),
                        icon: const Icon(Icons.filter_alt_off_rounded), label: const Text('Clear filters'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('${records.length} record${records.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [DataColumn(label: Text('Student')), DataColumn(label: Text('Class')), DataColumn(label: Text('Status')), DataColumn(label: Text('Method')), DataColumn(label: Text('Verified')), DataColumn(label: Text('Date / Time'))],
                      rows: records.map((document) {
                        final data = document.data();
                        final timestamp = data['timestamp'];
                        String dateText = '-';
                        if (timestamp is Timestamp) {
                          final date = timestamp.toDate();
                          dateText = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                        }
                        final verified = data['verified'] == true;
                        final studentId = data['student_id']?.toString() ?? '';
                        final storedName = data['student_name']?.toString().trim() ?? '';
                        final displayName = storedName.isNotEmpty ? storedName : userNames[studentId] ?? data['student_email']?.toString() ?? studentId;
                        return DataRow(cells: [
                          DataCell(Text(displayName.isEmpty ? 'Unknown student' : displayName)),
                          DataCell(Text(data['subject_code']?.toString() ?? data['class_id']?.toString() ?? '')),
                          DataCell(Text(data['status']?.toString() ?? '')),
                          DataCell(Text(data['verification_method']?.toString() ?? data['method']?.toString() ?? '')),
                          DataCell(Icon(verified ? Icons.check_circle_rounded : Icons.cancel_rounded, color: verified ? Colors.green : Colors.red)),
                          DataCell(Text(dateText)),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CLASSROOMS / GEOFENCE
  // ============================================================

  Widget _buildClassroomsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('classrooms').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorPage('Unable to load classrooms: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data!.docs;

        return _pageContainer(
          title: 'Classroom & Geofence Management',
          description:
              'Create classroom geofences here, then assign one to each subject in Class Management.',
          actionLabel: 'Add Classroom',
          actionIcon: Icons.add_location_alt_rounded,
          onAction: _showClassroomDialog,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Classroom')),
                DataColumn(label: Text('Building')),
                DataColumn(label: Text('Floor')),
                DataColumn(label: Text('Latitude')),
                DataColumn(label: Text('Longitude')),
                DataColumn(label: Text('Radius')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rooms.map((document) {
                final data = document.data();
                final active = data['active'] is bool
                    ? data['active'] as bool
                    : true;

                return DataRow(
                  cells: [
                    DataCell(Text(data['name']?.toString() ?? '')),
                    DataCell(Text(data['building']?.toString() ?? '')),
                    DataCell(Text(data['floor']?.toString() ?? '-')),
                    DataCell(Text(data['latitude']?.toString() ?? '')),
                    DataCell(Text(data['longitude']?.toString() ?? '')),
                    DataCell(Text('${data['radius_m'] ?? 0} m')),
                    DataCell(_statusChip(active)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () =>
                                _showClassroomDialog(existing: document),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmDeleteClassroom(document),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
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

  Future<void> _showClassroomDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final data = existing?.data() ?? <String, dynamic>{};

    final nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );
    final buildingController = TextEditingController(
      text: data['building']?.toString() ?? '',
    );
    final floorController = TextEditingController(
      text: data['floor']?.toString() ?? '',
    );
    final widthController = TextEditingController(
      text: data['width_m']?.toString() ?? '',
    );
    final lengthController = TextEditingController(
      text: data['length_m']?.toString() ?? '',
    );
    final latitudeController = TextEditingController(
      text: data['latitude']?.toString() ?? '',
    );
    final longitudeController = TextEditingController(
      text: data['longitude']?.toString() ?? '',
    );
    final radiusController = TextEditingController(
      text: data['radius_m']?.toString() ?? '30',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Classroom' : 'Edit Classroom'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Classroom Name',
                      hintText: 'CIT Laboratory 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: buildingController,
                    decoration: const InputDecoration(
                      labelText: 'Building',
                      hintText: 'CIT Building',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: floorController,
                    decoration: const InputDecoration(
                      labelText: 'Floor / Level',
                      hintText: '1st Floor',
                      helperText:
                          'Required for distinguishing rooms in multi-floor buildings.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lengthController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Room Length (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Room Width (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: radiusController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Allowed Radius (meters)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final latitude = double.tryParse(
                  latitudeController.text.trim(),
                );
                final longitude = double.tryParse(
                  longitudeController.text.trim(),
                );
                final radius = double.tryParse(radiusController.text.trim());
                final length = double.tryParse(lengthController.text.trim());
                final width = double.tryParse(widthController.text.trim());

                if (nameController.text.trim().isEmpty ||
                    floorController.text.trim().isEmpty ||
                    latitude == null ||
                    longitude == null ||
                    radius == null) {
                  _showMessage(
                    'Enter classroom name, floor, and valid latitude, longitude and radius.',
                  );
                  return;
                }
                if (radius < 3 || radius > 40) {
                  _showMessage(
                    'Use a measured classroom radius between 3 and 40 meters. Avoid oversized geofences.',
                  );
                  return;
                }

                final values = <String, dynamic>{
                  'name': nameController.text.trim(),
                  'building': buildingController.text.trim(),
                  'floor': floorController.text.trim(),
                  'length_m': length,
                  'width_m': width,
                  'latitude': latitude,
                  'longitude': longitude,
                  'radius_m': radius,
                  'active': true,
                  'updated_at': FieldValue.serverTimestamp(),
                };

                if (existing == null) {
                  values['created_at'] = FieldValue.serverTimestamp();
                  await _firestore.collection('classrooms').add(values);
                } else {
                  await existing.reference.update(values);
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _showMessage(
                  existing == null
                      ? 'Classroom created.'
                      : 'Classroom updated.',
                );
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteClassroom(
    QueryDocumentSnapshot<Map<String, dynamic>> classroom,
  ) async {
    final assignedClasses = await _firestore
        .collection('classes')
        .where('classroom_id', isEqualTo: classroom.id)
        .get();

    if (!mounted) return;

    if (assignedClasses.docs.isNotEmpty) {
      final data = classroom.data();
      _showMessage(
        '${data['name'] ?? 'This classroom'} is assigned to ${assignedClasses.docs.length} class(es). Reassign those classes before deleting it.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Classroom?'),
          content: Text(
            'Delete ${classroom.data()['name'] ?? 'this classroom'} and its geofence?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await classroom.reference.delete();
    _showMessage('Classroom deleted.');
  }

  // ============================================================
  // REPORTS
  // ============================================================

  Widget _buildReportsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('attendance').snapshots(),
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

          return true;
        }).toList();

        final summary = _reportSummary(records);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance Reports',
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
                  FilledButton.icon(
                    onPressed: records.isEmpty
                        ? null
                        : () =>
                              _showReportPreview(records, 'Attendance Reports'),
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
                  _AdminStatCard(
                    icon: Icons.list_alt_rounded,
                    title: 'Total Attendance',
                    value: summary['total'].toString(),
                  ),
                  _AdminStatCard(
                    icon: Icons.check_circle_rounded,
                    title: 'Present',
                    value: summary['present'].toString(),
                  ),
                  _AdminStatCard(
                    icon: Icons.schedule_rounded,
                    title: 'Late',
                    value: summary['late'].toString(),
                  ),
                  _AdminStatCard(
                    icon: Icons.cancel_rounded,
                    title: 'Absent',
                    value: summary['absent'].toString(),
                  ),
                  _AdminStatCard(
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


  Future<bool> _confirmBulkImport({
    required String title,
    required String fileName,
    required int validRows,
    required List<String> errors,
    required String template,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: $fileName'),
                const SizedBox(height: 8),
                Text('$validRows valid row${validRows == 1 ? '' : 's'} ready to import.'),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('${errors.length} row error${errors.length == 1 ? '' : 's'}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...errors.take(12).map((error) => Text('• $error')),
                  if (errors.length > 12) Text('• ...and ${errors.length - 12} more.'),
                ],
                const SizedBox(height: 18),
                const Text('Required CSV format', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(template, style: const TextStyle(fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: validRows > 0 && errors.isEmpty ? () => Navigator.pop(dialogContext, true) : null,
            child: const Text('Import'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _bulkUploadUsers() async {
    const template = 'email,first_name,last_name,role,id_number,course,year_level,department\nstudent@uls.edu.ph,Juan,Dela Cruz,student,24-00001,BSIT,4,';
    try {
      final picked = await BulkCsvService.pickCsv();
      if (picked == null) return;
      final errors = <String>[];
      final valid = <Map<String, dynamic>>[];
      final allowedRoles = {'student', 'instructor', 'admin'};
      for (var i = 0; i < picked.rows.length; i++) {
        final row = picked.rows[i];
        final line = i + 2;
        final email = row['email'] ?? '';
        final first = row['first_name'] ?? '';
        final last = row['last_name'] ?? '';
        final role = (row['role'] ?? 'student').toLowerCase();
        if (email.isEmpty || first.isEmpty || last.isEmpty) {
          errors.add('Line $line: email, first_name and last_name are required.');
          continue;
        }
        if (!allowedRoles.contains(role)) {
          errors.add('Line $line: role must be student, instructor or admin.');
          continue;
        }
        final year = int.tryParse(row['year_level'] ?? '') ?? 1;
        if (role == 'student') {
          final course = row['course'] ?? '';
          if (!_studentCourses.contains(course) || !_studentYearLevels.contains(year)) {
            errors.add('Line $line: student course/year must be one of ${_studentCourses.join(', ')} and year 1-4.');
            continue;
          }
          if ((row['id_number'] ?? '').isEmpty) {
            errors.add('Line $line: student id_number is required.');
            continue;
          }
        }
        valid.add({
          'email': email,
          'first_name': first,
          'last_name': last,
          'role': role,
          'id_number': row['id_number'] ?? '',
          'course': row['course'] ?? '',
          'year_level': year,
          'department': row['department'] ?? '',
        });
      }
      if (!mounted) return;
      final confirmed = await _confirmBulkImport(
        title: 'Bulk Invite Users',
        fileName: picked.fileName,
        validRows: valid.length,
        errors: errors,
        template: template,
      );
      if (!confirmed) return;

      var sent = 0;
      final failures = <String>[];
      for (final item in valid) {
        try {
          final role = item['role'] as String;
          final result = await AccountOnboardingService.inviteUser(
            email: item['email'] as String,
            firstName: item['first_name'] as String,
            lastName: item['last_name'] as String,
            role: role,
            studentNumber: role == 'student' ? item['id_number'] as String : '',
            course: role == 'student' ? item['course'] as String : '',
            yearLevel: item['year_level'] as int,
            employeeNumber: role == 'student' ? '' : item['id_number'] as String,
            department: role == 'student' ? '' : item['department'] as String,
          );
          if (result['success'] == true) {
            sent++;
          } else {
            failures.add('${item['email']}: ${result['message']}');
          }
        } catch (error) {
          failures.add('${item['email']}: $error');
        }
      }
      if (failures.isEmpty) {
        _showMessage('$sent invitation${sent == 1 ? '' : 's'} sent.');
      } else {
        _showMessage('$sent sent; ${failures.length} failed. First error: ${failures.first}');
      }
    } catch (error) {
      _showMessage('Unable to bulk invite users: $error');
    }
  }

  Future<void> _bulkUploadClasses() async {
    const template = 'subject_code,subject_name,section,classroom_name,schedule_day,start_time,end_time,semester,instructor_email\nIT101,Sample Subject,4A,Lab 1,Monday,08:00,09:30,1st Semester,instructor@example.edu';
    try {
      final picked = await BulkCsvService.pickCsv();
      if (picked == null) return;
      final classrooms = (await _firestore.collection('classrooms').get()).docs;
      final users = (await _firestore.collection('users').get()).docs;
      final errors = <String>[];
      final valid = <Map<String, dynamic>>[];
      for (var i = 0; i < picked.rows.length; i++) {
        final row = picked.rows[i];
        final line = i + 2;
        final code = row['subject_code'] ?? '';
        final name = row['subject_name'] ?? '';
        final roomName = row['classroom_name'] ?? '';
        if (code.isEmpty || name.isEmpty || roomName.isEmpty) {
          errors.add('Line $line: subject_code, subject_name and classroom_name are required.');
          continue;
        }
        final roomMatches = classrooms.where((doc) => (doc.data()['name']?.toString() ?? '').toLowerCase() == roomName.toLowerCase() && doc.data()['active'] != false).toList();
        if (roomMatches.length != 1) {
          errors.add('Line $line: classroom "$roomName" was not found uniquely as an active classroom.');
          continue;
        }
        final instructorEmail = row['instructor_email'] ?? '';
        QueryDocumentSnapshot<Map<String, dynamic>>? instructor;
        if (instructorEmail.isNotEmpty) {
          final matches = users.where((doc) => doc.data()['role'] == 'instructor' && (doc.data()['email']?.toString() ?? '').toLowerCase() == instructorEmail.toLowerCase()).toList();
          if (matches.length != 1) {
            errors.add('Line $line: instructor "$instructorEmail" was not found uniquely.');
            continue;
          }
          instructor = matches.first;
        }
        final room = roomMatches.first;
        final instructorData = instructor?.data();
        valid.add({
          'subject_code': code,
          'subject_name': name,
          'section': row['section'] ?? '',
          'classroom_id': room.id,
          'classroom_name': roomName,
          'room': roomName,
          'schedule_day': row['schedule_day'] ?? '',
          'start_time': row['start_time'] ?? '',
          'end_time': row['end_time'] ?? '',
          'semester': row['semester'] ?? '',
          'instructor_id': instructor?.id ?? '',
          'instructor_name': instructorData == null ? '' : '${instructorData['first_name'] ?? ''} ${instructorData['last_name'] ?? ''}'.trim(),
          'active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      final confirmed = await _confirmBulkImport(title: 'Bulk Upload Classes', fileName: picked.fileName, validRows: valid.length, errors: errors, template: template);
      if (!confirmed) return;
      final batch = _firestore.batch();
      for (final data in valid) {
        batch.set(_firestore.collection('classes').doc(), data);
      }
      await batch.commit();
      _showMessage('${valid.length} class${valid.length == 1 ? '' : 'es'} imported.');
    } catch (error) {
      _showMessage('Unable to bulk upload classes: $error');
    }
  }

  Future<void> _bulkUploadEnrollments() async {
    const template = 'student_email,subject_code,section\nstudent@example.edu,IT101,4A';
    try {
      final picked = await BulkCsvService.pickCsv();
      if (picked == null) return;
      final users = (await _firestore.collection('users').get()).docs;
      final classes = (await _firestore.collection('classes').get()).docs;
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
        final studentMatches = users.where((doc) => doc.data()['role'] == 'student' && (doc.data()['email']?.toString() ?? '').toLowerCase() == email.toLowerCase()).toList();
        final classMatches = classes.where((doc) => (doc.data()['subject_code']?.toString() ?? '').toLowerCase() == code.toLowerCase() && (section.isEmpty || (doc.data()['section']?.toString() ?? '').toLowerCase() == section.toLowerCase()) && doc.data()['active'] != false).toList();
        if (studentMatches.length != 1) {
          errors.add('Line $line: student "$email" was not found uniquely.');
          continue;
        }
        if (classMatches.length != 1) {
          errors.add('Line $line: class "$code"${section.isEmpty ? '' : ' section $section'} was not found uniquely.');
          continue;
        }
        final student = studentMatches.first;
        final classDoc = classMatches.first;
        final key = '${student.id}|${classDoc.id}';
        final duplicate = existing.any((doc) => doc.data()['student_id'] == student.id && doc.data()['class_id'] == classDoc.id && doc.data()['active'] != false);
        if (duplicate || !seen.add(key)) {
          errors.add('Line $line: student is already enrolled in this class or duplicated in the CSV.');
          continue;
        }
        final sd = student.data();
        final cd = classDoc.data();
        valid.add({
          'student_id': student.id,
          'student_name': '${sd['first_name'] ?? ''} ${sd['last_name'] ?? ''}'.trim(),
          'student_email': sd['email']?.toString() ?? '',
          'student_number': sd['student_number']?.toString() ?? '',
          'course': sd['course']?.toString() ?? '',
          'year_level': sd['year_level'],
          'class_id': classDoc.id,
          'subject_code': cd['subject_code']?.toString() ?? '',
          'subject_name': cd['subject_name']?.toString() ?? '',
          'section': cd['section']?.toString() ?? '',
          'instructor_id': cd['instructor_id']?.toString() ?? '',
          'instructor_name': cd['instructor_name']?.toString() ?? '',
          'room': cd['room']?.toString() ?? '',
          'schedule_day': cd['schedule_day']?.toString() ?? '',
          'start_time': cd['start_time']?.toString() ?? '',
          'end_time': cd['end_time']?.toString() ?? '',
          'semester': cd['semester']?.toString() ?? '',
          'active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      final confirmed = await _confirmBulkImport(title: 'Bulk Upload Enrollments', fileName: picked.fileName, validRows: valid.length, errors: errors, template: template);
      if (!confirmed) return;
      final batch = _firestore.batch();
      for (final data in valid) {
        batch.set(_firestore.collection('enrollments').doc(), data);
      }
      await batch.commit();
      await EnrollmentNotificationService.createForEnrollments(valid);
      _showMessage('${valid.length} enrollment${valid.length == 1 ? '' : 's'} imported. Students will see the class and an enrollment notification in the mobile app.');
    } catch (error) {
      _showMessage('Unable to bulk upload enrollments: $error');
    }
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
                  'Administrator Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 28),
                _profileRow('Name', _fullName),
                _profileRow('Email', _email),
                _profileRow('Role', 'Admin'),
                _profileRow(
                  'Department',
                  _department.isEmpty ? 'Administration' : _department,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================

  Widget _pageContainer({
    required String title,
    required String description,
    required Widget child,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
    String? secondaryActionLabel,
    IconData? secondaryActionIcon,
    VoidCallback? onSecondaryAction,
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
                  if (onSecondaryAction != null && secondaryActionLabel != null) ...[
                    OutlinedButton.icon(
                      onPressed: onSecondaryAction,
                      icon: Icon(secondaryActionIcon ?? Icons.upload_file_rounded),
                      label: Text(secondaryActionLabel),
                    ),
                    const SizedBox(width: 10),
                  ],
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

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          Icon(icon, size: 70, color: const Color(0xFFBCCCDC)),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334E68),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF829AB1)),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String role) {
    final normalized = role.toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'admin':
        background = const Color(0xFFE8EAF6);
        foreground = const Color(0xFF2F64D6);
        break;
      case 'instructor':
        background = const Color(0xFFE3F2FD);
        foreground = const Color(0xFF21449C);
        break;
      default:
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.isEmpty ? 'Unknown' : role,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
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

class _AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _AdminStatCard({
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
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2F64D6)),
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
