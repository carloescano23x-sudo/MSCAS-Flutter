import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/enrollment_notification_service.dart';
import '../../services/notification_service.dart';
import '../../services/offline_attendance_service.dart';
import 'attendance_history.dart';
import 'class_list.dart';
import 'profile_screen.dart';
import 'shared_face_attendance.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => StudentDashboardState();
}

class StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;

  StreamSubscription<AttendanceSessionNotice>? _noticeSubscription;
  StreamSubscription<OfflineSyncNotice>? _offlineSyncSubscription;
  StreamSubscription<List<EnrollmentNotice>>? _enrollmentNoticeSubscription;
  final Set<String> _announcedEnrollmentNotices = <String>{};

  final List<String> _titles = const [
    'MSCAS',
    'Shared Scan',
    'Attendance History',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();

    _noticeSubscription = NotificationService.instance.notices.listen(
      _showAttendanceNotice,
    );

    NotificationService.instance.initializeForSignedInUser();

    _enrollmentNoticeSubscription =
        EnrollmentNotificationService.instance.watchMine().listen((notices) {
      if (!mounted) return;
      final unread = notices.where((notice) => !notice.read).toList();
      if (unread.isEmpty) return;
      final newest = unread.first;
      if (!_announcedEnrollmentNotices.add(newest.id)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newest.message),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              _showEnrollmentNotifications();
            },
          ),
        ),
      );
    });

    _offlineSyncSubscription = OfflineAttendanceService.instance.syncNotices.listen((
      notice,
    ) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notice.remaining == 0
                ? '${notice.synced} pending attendance record(s) synced successfully.'
                : '${notice.synced} attendance record(s) synced. ${notice.remaining} still pending.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    });

    OfflineAttendanceService.instance.startAutoSync();
  }

  Widget _selectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const ClassList();
      case 1:
        // IMPORTANT: SharedFaceAttendance is constructed only when this tab
        // is selected. Leaving the tab disposes its timer and camera.
        return const SharedFaceAttendance();
      case 2:
        return const AttendanceHistory();
      case 3:
        return const ProfileScreen();
      default:
        return const ClassList();
    }
  }

  void _showAttendanceNotice(AttendanceSessionNotice notice) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: const Color(0xFFEAF0FF),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                notice.message,
                style: const TextStyle(color: AppTheme.textMuted, height: 1.3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();

                if (!mounted) return;

                setState(() {
                  // Open Classes where the student can see
                  // Attendance Open and choose Face/PIN.
                  _selectedIndex = 0;
                });
              },
              child: const Text('VIEW CLASS'),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
              },
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
  }

  Future<void> _showEnrollmentNotifications() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enrollment Notifications'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: StreamBuilder<List<EnrollmentNotice>>(
              stream: EnrollmentNotificationService.instance.watchMine(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Unable to load notifications: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notices = snapshot.data!;
                if (notices.isEmpty) {
                  return const Center(child: Text('No enrollment notifications yet.'));
                }
                return ListView.separated(
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notice = notices[index];
                    return ListTile(
                      leading: Icon(
                        notice.read
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_rounded,
                      ),
                      title: Text(
                        notice.message,
                        style: TextStyle(
                          fontWeight: notice.read
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text('Enrollment'),
                      onTap: () async {
                        await EnrollmentNotificationService.instance
                            .markRead(notice.id);
                        if (!mounted) return;
                        setState(() => _selectedIndex = 0);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await EnrollmentNotificationService.instance.markAllRead();
              },
              child: const Text('Mark all read'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await NotificationService.instance.removeCurrentToken();

    final authService = AuthService();
    await authService.logout();

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
      backgroundColor: AppTheme.background,
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              title: Text(
                _titles[_selectedIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              actions: [
                StreamBuilder<List<EnrollmentNotice>>(
                  stream: EnrollmentNotificationService.instance.watchMine(),
                  builder: (context, snapshot) {
                    final unread = snapshot.data
                            ?.where((notice) => !notice.read)
                            .length ??
                        0;
                    return Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: IconButton(
                        tooltip: 'Enrollment notifications',
                        onPressed: _showEnrollmentNotifications,
                        icon: Icon(
                          unread > 0
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _logout,
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: _selectedPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_retouching_natural_outlined),
            selectedIcon: Icon(Icons.face_retouching_natural_rounded),
            label: 'Shared Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noticeSubscription?.cancel();
    _offlineSyncSubscription?.cancel();
    _enrollmentNoticeSubscription?.cancel();
    OfflineAttendanceService.instance.stopAutoSync();
    super.dispose();
  }
}
