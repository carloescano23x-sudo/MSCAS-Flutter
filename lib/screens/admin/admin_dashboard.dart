import '../../services/supabase_firestore_compat.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  int _selectedIndex = 0;

  final _titles = const [
    'Admin Dashboard',
    'Users',
    'Classrooms',
    'Classes',
    'Enrollments',
    'Attendance',
  ];

  Future<void> _logout() async {
    await _authService.logout();

    Fluttertoast.showToast(
      msg: 'Logged out successfully',
      backgroundColor: Colors.green,
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _AdminHomePage(),
          _AdminUsersPage(),
          _AdminClassroomsPage(),
          _AdminClassesPage(),
          _AdminEnrollmentsPage(),
          _AdminAttendancePage(),
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
            icon: Icon(Icons.people_alt_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_rounded),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.class_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_add_rounded),
            label: 'Enroll',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_rounded),
            label: 'Attendance',
          ),
        ],
      ),
    );
  }
}

class _AdminHomePage extends StatelessWidget {
  const _AdminHomePage();

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        int students = 0;
        int instructors = 0;
        int admins = 0;

        for (final doc in userSnapshot.data?.docs ?? []) {
          final role = doc.data()['role']?.toString().trim().toLowerCase();

          if (role == 'student') {
            students++;
          } else if (role == 'instructor') {
            instructors++;
          } else if (role == 'admin') {
            admins++;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('classes').snapshots(),
          builder: (context, classSnapshot) {
            final classes = classSnapshot.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('attendance').snapshots(),
              builder: (context, attendanceSnapshot) {
                final attendance = attendanceSnapshot.data?.docs.length ?? 0;

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 250),
                    );
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'MSCAS Administration',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Live data from the same Supabase project used by the web portal.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 22),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          _StatCard(
                            title: 'Students',
                            value: students.toString(),
                            icon: Icons.school_rounded,
                          ),
                          _StatCard(
                            title: 'Instructors',
                            value: instructors.toString(),
                            icon: Icons.badge_rounded,
                          ),
                          _StatCard(
                            title: 'Classes',
                            value: classes.toString(),
                            icon: Icons.class_rounded,
                          ),
                          _StatCard(
                            title: 'Attendance',
                            value: attendance.toString(),
                            icon: Icons.fact_check_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Role Overview',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _countRow('Administrators', admins),
                              _countRow('Instructors', instructors),
                              _countRow('Students', students),
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

  Widget _countRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AdminUsersPage extends StatelessWidget {
  const _AdminUsersPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load users: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.toList();

        users.sort((a, b) {
          final aName =
              '${a.data()['first_name'] ?? ''} ${a.data()['last_name'] ?? ''}'
                  .toLowerCase();
          final bName =
              '${b.data()['first_name'] ?? ''} ${b.data()['last_name'] ?? ''}'
                  .toLowerCase();
          return aName.compareTo(bName);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final document = users[index];
            final data = document.data();

            final name =
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();

            final role = data['role']?.toString().toLowerCase() ?? 'unknown';

            final active = data['active'] is bool
                ? data['active'] as bool
                : true;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    role == 'admin'
                        ? Icons.admin_panel_settings_rounded
                        : role == 'instructor'
                        ? Icons.badge_rounded
                        : Icons.school_rounded,
                  ),
                ),
                title: Text(name.isEmpty ? 'Unnamed user' : name),
                subtitle: Text('${data['email'] ?? ''}\n${role.toUpperCase()}'),
                isThreeLine: true,
                trailing: Switch(
                  value: active,
                  onChanged: (value) async {
                    await document.reference.update({
                      'active': value,
                      'updated_at': FieldValue.serverTimestamp(),
                    });
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminClassroomsPage extends StatefulWidget {
  const _AdminClassroomsPage();

  @override
  State<_AdminClassroomsPage> createState() => _AdminClassroomsPageState();
}

class _AdminClassroomsPageState extends State<_AdminClassroomsPage> {
  final LocationService _locationService = LocationService();
  bool _capturing = false;

  Future<void> _showClassroomDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final data = existing?.data() ?? <String, dynamic>{};
    final nameController = TextEditingController(text: data['name']?.toString() ?? '');
    final buildingController = TextEditingController(text: data['building']?.toString() ?? '');
    final floorController = TextEditingController(text: data['floor']?.toString() ?? '');
    final radiusController = TextEditingController(text: data['radius']?.toString() ?? '10');
    double? latitude = (data['latitude'] as num?)?.toDouble();
    double? longitude = (data['longitude'] as num?)?.toDouble();
    double? accuracy;
    bool active = data['active'] is bool ? data['active'] as bool : true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Classroom Location' : 'Edit Classroom Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Classroom Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: buildingController, decoration: const InputDecoration(labelText: 'Building', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Floor / Level', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: radiusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Geofence Radius (3-40 meters)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Phone Geolocation', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(latitude == null ? 'No coordinates captured yet.' : 'Latitude: ${latitude!.toStringAsFixed(7)}\nLongitude: ${longitude!.toStringAsFixed(7)}${accuracy == null ? '' : '\nAccuracy: ±${accuracy!.toStringAsFixed(1)} m'}'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _capturing ? null : () async {
                        setState(() => _capturing = true);
                        final position = await _locationService.getCurrentLocation();
                        if (mounted) setState(() => _capturing = false);
                        if (position == null) {
                          Fluttertoast.showToast(msg: 'Unable to capture location. Enable GPS and location permission.', backgroundColor: Colors.orange);
                          return;
                        }
                        setDialogState(() {
                          latitude = position.latitude;
                          longitude = position.longitude;
                          accuracy = position.accuracy;
                        });
                      },
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(_capturing ? 'Capturing...' : 'Capture Current Location'),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active classroom'), value: active, onChanged: (value) => setDialogState(() => active = value)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final radius = int.tryParse(radiusController.text.trim());
                if (nameController.text.trim().isEmpty || floorController.text.trim().isEmpty || latitude == null || longitude == null || radius == null || radius < 3 || radius > 40) {
                  Fluttertoast.showToast(msg: 'Enter a classroom name and floor, capture the phone location, and use a 3-40 m radius.', backgroundColor: Colors.orange);
                  return;
                }
                final values = <String, dynamic>{
                  'name': nameController.text.trim(), 'building': buildingController.text.trim(), 'floor': floorController.text.trim(),
                  'latitude': latitude, 'longitude': longitude, 'radius': radius, 'active': active, 'updated_at': FieldValue.serverTimestamp(),
                };
                if (existing == null) {
                  values['created_at'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('classrooms').add(values);
                } else {
                  await existing.reference.update(values);
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                Fluttertoast.showToast(msg: existing == null ? 'Classroom location saved.' : 'Classroom location updated.', backgroundColor: Colors.green);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('classrooms').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Unable to load classrooms: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) => (a.data()['name']?.toString() ?? '').compareTo(b.data()['name']?.toString() ?? ''));
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _showClassroomDialog(), icon: const Icon(Icons.add_location_alt_rounded), label: const Text('Add')),
          body: docs.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No classrooms yet. Tap Add and capture the classroom location using this phone.')))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index]; final data = doc.data();
                    return Card(child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.location_on_rounded)),
                      title: Text(data['name']?.toString() ?? 'Classroom'),
                      subtitle: Text('${data['building'] ?? ''} • Floor ${data['floor'] ?? '-'}\n${data['latitude'] ?? '-'}, ${data['longitude'] ?? '-'} • ${data['radius'] ?? '-'} m'),
                      isThreeLine: true,
                      trailing: IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _showClassroomDialog(existing: doc)),
                    ));
                  },
                ),
        );
      },
    );
  }
}

class _AdminClassesPage extends StatelessWidget {
  const _AdminClassesPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('classes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load classes: ${snapshot.error}'),
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
          return const Center(
            child: Text(
              'No classes yet. Create classes from the Admin web portal.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final data = classes[index].data();

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.class_rounded)),
                title: Text(
                  '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''}',
                ),
                subtitle: Text(
                  '${data['section'] ?? ''}\n'
                  '${data['instructor_name'] ?? 'No instructor'} • ${data['room'] ?? 'No room'}\n'
                  '${data['schedule_day'] ?? ''} ${data['start_time'] ?? ''} - ${data['end_time'] ?? ''}',
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

class _AdminEnrollmentsPage extends StatelessWidget {
  const _AdminEnrollmentsPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('enrollments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load enrollments: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final grouped =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

        for (final doc in docs) {
          final studentId = doc.data()['student_id']?.toString() ?? '';
          if (studentId.isEmpty) continue;

          grouped.putIfAbsent(studentId, () => []).add(doc);
        }

        if (grouped.isEmpty) {
          return const Center(child: Text('No student enrollments yet.'));
        }

        final entries = grouped.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final enrollments = entries[index].value;
            final first = enrollments.first.data();

            return Card(
              child: ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                title: Text(first['student_name']?.toString() ?? 'Student'),
                subtitle: Text(
                  '${first['student_email'] ?? ''} • ${enrollments.length} subject${enrollments.length == 1 ? '' : 's'}',
                ),
                children: enrollments.map((doc) {
                  final data = doc.data();

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(
                      '${data['subject_code'] ?? ''} - ${data['subject_name'] ?? ''}',
                    ),
                    subtitle: Text(data['section']?.toString() ?? ''),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminAttendancePage extends StatelessWidget {
  const _AdminAttendancePage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load attendance: ${snapshot.error}'),
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

        if (records.isEmpty) {
          return const Center(child: Text('No attendance records yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final data = records[index].data();
            final status = data['status']?.toString() ?? 'unknown';

            return Card(
              child: ListTile(
                leading: Icon(
                  status.toLowerCase() == 'present'
                      ? Icons.check_circle_rounded
                      : status.toLowerCase() == 'late'
                      ? Icons.schedule_rounded
                      : Icons.cancel_rounded,
                ),
                title: Text(data['student_name']?.toString() ?? 'Student'),
                subtitle: Text(
                  '${data['subject_code'] ?? ''} ${data['section'] ?? ''}\n'
                  '${data['verification_method'] ?? data['method'] ?? ''} • ${_formatTimestamp(data['timestamp'])}',
                ),
                isThreeLine: true,
                trailing: Text(
                  status.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.month}/${date.day}/${date.year} $hour:$minute $period';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
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
