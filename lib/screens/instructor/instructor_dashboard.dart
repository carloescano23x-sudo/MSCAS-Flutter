import 'dart:math';

import '../../services/supabase_firestore_compat.dart';
import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../services/auth_service.dart';
import '../../services/session_time_service.dart';

class InstructorDashboard extends StatefulWidget {
  const InstructorDashboard({super.key});

  @override
  State<InstructorDashboard> createState() => InstructorDashboardState();
}

class InstructorDashboardState extends State<InstructorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  int _selectedIndex = 0;

  final _titles = const [
    'Instructor Dashboard',
    'Classes',
    'Sessions',
    'PIN Fallback',
    'Attendance',
  ];

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<void> _logout() async {
    await _authService.logout();

    Fluttertoast.showToast(
      msg: 'Logged out successfully',
      backgroundColor: Colors.green,
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myClasses() {
    if (_uid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('classes')
        .where('instructor_id', isEqualTo: _uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _mySessions() {
    if (_uid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('attendance_sessions')
        .where('instructor_id', isEqualTo: _uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myAttendance() {
    if (_uid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('attendance')
        .where('instructor_id', isEqualTo: _uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _InstructorHomePage(
            classes: _myClasses(),
            attendance: _myAttendance(),
          ),
          _InstructorClassesPage(
            classes: _myClasses(),
            onStartSession: _startSession,
          ),
          _InstructorSessionsPage(sessions: _mySessions()),
          _InstructorPinPage(classes: _myClasses(), instructorId: _uid),
          _InstructorAttendancePage(attendance: _myAttendance()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.class_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_rounded),
            label: 'Sessions',
          ),
          NavigationDestination(icon: Icon(Icons.pin_rounded), label: 'PIN'),
          NavigationDestination(
            icon: Icon(Icons.fact_check_rounded),
            label: 'Records',
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(
    String classId,
    Map<String, dynamic> classData,
  ) async {
    final existing = await _firestore
        .collection('attendance_sessions')
        .where('class_id', isEqualTo: classId)
        .where('active', isEqualTo: true)
        .get();

    if (existing.docs.any((doc) => SessionTimeService.isOpen(doc.data()))) {
      Fluttertoast.showToast(
        msg: 'This class already has an active session.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final scheduleError = SessionTimeService.validateStart(classData);
    if (scheduleError != null) {
      Fluttertoast.showToast(
        msg: scheduleError,
        backgroundColor: Colors.orange,
      );
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
      'instructor_id': _uid,
      'instructor_name': classData['instructor_name'] ?? '',
      'active': true,
      ...timeFields,
      'created_at': FieldValue.serverTimestamp(),
      'closed_at': null,
    });

    Fluttertoast.showToast(
      msg: 'Attendance session started.',
      backgroundColor: Colors.green,
    );
  }
}

class _InstructorHomePage extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> classes;
  final Stream<QuerySnapshot<Map<String, dynamic>>> attendance;

  const _InstructorHomePage({required this.classes, required this.attendance});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: classes,
      builder: (context, classSnapshot) {
        final classDocs = classSnapshot.data?.docs ?? [];
        final classIds = classDocs.map((doc) => doc.id).toSet();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('enrollments')
              .snapshots(),
          builder: (context, enrollmentSnapshot) {
            final enrollments = enrollmentSnapshot.data?.docs ?? [];

            final studentIds = enrollments
                .where(
                  (doc) =>
                      classIds.contains(doc.data()['class_id']?.toString()),
                )
                .map((doc) => doc.data()['student_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: attendance,
              builder: (context, attendanceSnapshot) {
                final records = attendanceSnapshot.data?.docs ?? [];

                int present = 0;
                int late = 0;
                int absent = 0;

                for (final doc in records) {
                  final status = doc.data()['status']?.toString().toLowerCase();

                  if (status == 'present') {
                    present++;
                  } else if (status == 'late') {
                    late++;
                  } else if (status == 'absent') {
                    absent++;
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Instructor Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _InstructorStatCard(
                          title: 'Classes',
                          value: classDocs.length.toString(),
                          icon: Icons.class_rounded,
                        ),
                        _InstructorStatCard(
                          title: 'Students',
                          value: studentIds.length.toString(),
                          icon: Icons.people_alt_rounded,
                        ),
                        _InstructorStatCard(
                          title: 'Present',
                          value: present.toString(),
                          icon: Icons.check_circle_rounded,
                        ),
                        _InstructorStatCard(
                          title: 'Late / Absent',
                          value: '${late + absent}',
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _InstructorClassesPage extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> classes;
  final Future<void> Function(String, Map<String, dynamic>) onStartSession;

  const _InstructorClassesPage({
    required this.classes,
    required this.onStartSession,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: classes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('No classes are assigned to this instructor.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            return Card(
              child: ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.class_rounded)),
                title: Text(
                  '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''}',
                ),
                subtitle: Text(
                  '${data['section'] ?? ''} • ${data['room'] ?? ''}',
                ),
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(
                      '${data['schedule_day'] ?? ''} ${data['start_time'] ?? ''} - ${data['end_time'] ?? ''}',
                    ),
                  ),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('enrollments')
                        .where('class_id', isEqualTo: doc.id)
                        .get(),
                    builder: (context, enrolledSnapshot) {
                      final count = enrolledSnapshot.data?.docs.length ?? 0;

                      return ListTile(
                        leading: const Icon(Icons.people_rounded),
                        title: Text(
                          '$count enrolled student${count == 1 ? '' : 's'}',
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: data['active'] == false
                            ? null
                            : () => onStartSession(doc.id, data),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Attendance Session'),
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
}

class _InstructorSessionsPage extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> sessions;

  const _InstructorSessionsPage({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sessions,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
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

        if (docs.isEmpty) {
          return const Center(child: Text('No attendance sessions yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final active = data['active'] == true;
            final open = SessionTimeService.isOpen(data);
            final expired = SessionTimeService.isExpired(data);
            final endAt = SessionTimeService.effectiveEnd(data);

            return Card(
              child: ListTile(
                leading: Icon(
                  open ? Icons.play_circle_rounded : Icons.stop_circle_rounded,
                ),
                title: Text(
                  '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''}',
                ),
                subtitle: Text(
                  '${data['section'] ?? ''}\n${_formatTimestamp(data['created_at'])}'
                  '${endAt == null ? '' : '\nEnds: ${SessionTimeService.formatClock(endAt)}'}'
                  '${expired ? '\nTime ended - extension available' : ''}',
                ),
                isThreeLine: true,
                trailing: active
                    ? Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'Extend 15 minutes',
                            onPressed: () async {
                              final newEnd = SessionTimeService.extend(
                                data,
                                15,
                              );
                              await doc.reference.update({
                                'effective_end_at': Timestamp.fromDate(newEnd),
                                'extended': true,
                                'extension_minutes': FieldValue.increment(15),
                                'last_extended_at':
                                    FieldValue.serverTimestamp(),
                              });
                              Fluttertoast.showToast(
                                msg:
                                    'Extended until ${SessionTimeService.formatClock(newEnd)}',
                              );
                            },
                            icon: const Icon(Icons.more_time_rounded),
                          ),
                          IconButton(
                            tooltip: 'Close session',
                            onPressed: () async {
                              await doc.reference.update({
                                'active': false,
                                'closed_at': FieldValue.serverTimestamp(),
                                'close_reason': 'manual',
                              });
                            },
                            icon: const Icon(Icons.stop_circle_rounded),
                          ),
                        ],
                      )
                    : const Text('Closed'),
              ),
            );
          },
        );
      },
    );
  }
}

class _InstructorPinPage extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> classes;
  final String instructorId;

  const _InstructorPinPage({required this.classes, required this.instructorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: classes,
      builder: (context, classSnapshot) {
        if (!classSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final classDocs = classSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pin_sessions')
              .where('instructor_id', isEqualTo: instructorId)
              .snapshots(),
          builder: (context, pinSnapshot) {
            final pinDocs = pinSnapshot.data?.docs ?? [];

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                FilledButton.icon(
                  onPressed: classDocs.isEmpty
                      ? null
                      : () => _showGeneratePinDialog(context, classDocs),
                  icon: const Icon(Icons.pin_rounded),
                  label: const Text('Generate PIN'),
                ),
                const SizedBox(height: 14),
                ...pinDocs.map((doc) {
                  final data = doc.data();
                  final active = _isActive(data);

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.pin_rounded),
                      ),
                      title: Text(
                        data['pin']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      subtitle: Text(
                        '${data['subject_code'] ?? ''} ${data['section'] ?? ''}\n'
                        'Expires: ${_formatTimestamp(data['expires_at'])}',
                      ),
                      isThreeLine: true,
                      trailing: active
                          ? IconButton(
                              onPressed: () async {
                                await doc.reference.update({
                                  'active': false,
                                  'closed_at': FieldValue.serverTimestamp(),
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : const Text('Expired'),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  bool _isActive(Map<String, dynamic> data) {
    if (data['active'] != true) return false;

    final expiresAt = data['expires_at'];
    return expiresAt is Timestamp && expiresAt.toDate().isAfter(DateTime.now());
  }

  Future<void> _showGeneratePinDialog(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
  ) async {
    String? selectedClassId;
    int duration = 10;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Generate PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: classes.map((doc) {
                      final data = doc.data();

                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(
                          '${data['subject_code'] ?? ''} ${data['section'] ?? ''}',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedClassId = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: duration,
                    decoration: const InputDecoration(
                      labelText: 'Validity',
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
                      setDialogState(() => duration = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedClassId == null
                      ? null
                      : () async {
                          final classDoc = classes.firstWhere(
                            (doc) => doc.id == selectedClassId,
                          );

                          final data = classDoc.data();

                          final existing = await FirebaseFirestore.instance
                              .collection('pin_sessions')
                              .where('class_id', isEqualTo: classDoc.id)
                              .where('active', isEqualTo: true)
                              .get();

                          for (final pin in existing.docs) {
                            await pin.reference.update({
                              'active': false,
                              'closed_at': FieldValue.serverTimestamp(),
                            });
                          }

                          final pin = (100000 + Random.secure().nextInt(900000))
                              .toString();

                          await FirebaseFirestore.instance
                              .collection('pin_sessions')
                              .add({
                                'class_id': classDoc.id,
                                'subject_code': data['subject_code'] ?? '',
                                'subject_name': data['subject_name'] ?? '',
                                'section': data['section'] ?? '',
                                'instructor_id': instructorId,
                                'instructor_name':
                                    data['instructor_name'] ?? '',
                                'pin': pin,
                                'active': true,
                                'created_at': FieldValue.serverTimestamp(),
                                'expires_at': Timestamp.fromDate(
                                  DateTime.now().add(
                                    Duration(minutes: duration),
                                  ),
                                ),
                              });

                          if (!dialogContext.mounted) {
                            return;
                          }

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
}

class _InstructorAttendancePage extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> attendance;

  const _InstructorAttendancePage({required this.attendance});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: attendance,
      builder: (context, snapshot) {
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

        if (records.isEmpty) {
          return const Center(child: Text('No attendance records yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final data = records[index].data();

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.fact_check_rounded),
                ),
                title: Text(data['student_name']?.toString() ?? 'Student'),
                subtitle: Text(
                  '${data['subject_code'] ?? ''} ${data['section'] ?? ''}\n'
                  '${data['status'] ?? ''} • ${data['verification_method'] ?? data['method'] ?? ''}\n'
                  '${_formatTimestamp(data['timestamp'])}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _InstructorStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InstructorStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue.shade700),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(dynamic value) {
  if (value is! Timestamp) return '-';

  final date = value.toDate();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '${date.month}/${date.day}/${date.year} $hour:$minute $period';
}
