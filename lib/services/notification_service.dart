import 'dart:async';

import 'supabase_firestore_compat.dart';
import 'supabase_auth_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_time_service.dart';

class AttendanceSessionNotice {
  final String sessionId;
  final String classId;
  final String subjectCode;
  final String subjectName;
  final String section;

  const AttendanceSessionNotice({
    required this.sessionId,
    required this.classId,
    required this.subjectCode,
    required this.subjectName,
    required this.section,
  });

  String get title => 'Attendance Started';

  String get message {
    final code = subjectCode.trim();
    final name = subjectName.trim();
    final sec = section.trim();

    final subject = [
      if (code.isNotEmpty) code,
      if (name.isNotEmpty) name,
    ].join(' - ');

    final label = subject.isEmpty ? 'Your class' : subject;

    return sec.isEmpty
        ? '$label attendance is now open.'
        : '$label ($sec) attendance is now open.';
  }
}

/// Free notification layer for MSCAS.
///
/// This does NOT use FCM or Cloud Functions. It listens to Firestore while the
/// Student app is running and emits a notice when an enrolled class gets an
/// active attendance session.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<AttendanceSessionNotice> _noticeController =
      StreamController<AttendanceSessionNotice>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _enrollmentSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionSubscription;

  final Set<String> _enrolledClassIds = <String>{};
  final Set<String> _notifiedSessionIds = <String>{};

  String? _initializedUid;
  bool _checkingSessions = false;

  Stream<AttendanceSessionNotice> get notices => _noticeController.stream;

  Future<void> initializeForSignedInUser() async {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    if (_initializedUid == uid) {
      await _checkActiveSessions();
      return;
    }

    await _cancelFirestoreListeners();

    _initializedUid = uid;
    _enrolledClassIds.clear();
    _notifiedSessionIds.clear();

    await _loadRememberedSessions(uid);
    await _loadCurrentEnrollments(uid);

    _enrollmentSubscription = _firestore
        .collection('enrollments')
        .where('student_id', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) async {
            _replaceEnrollmentIds(snapshot.docs);
            await _checkActiveSessions();
          },
          onError: (Object error) {
            debugPrint('MSCAS enrollment notification listener error: $error');
          },
        );

    _sessionSubscription = _firestore
        .collection('attendance_sessions')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) async {
            for (final document in snapshot.docs) {
              await _processSessionDocument(document);
            }
          },
          onError: (Object error) {
            debugPrint('MSCAS attendance notification listener error: $error');
          },
        );

    // Also catches a session that was already active when the student opened
    // the app, rather than requiring another instructor-side change.
    await _checkActiveSessions();
  }

  Future<void> _loadCurrentEnrollments(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('student_id', isEqualTo: uid)
          .get();

      _replaceEnrollmentIds(snapshot.docs);
    } catch (error) {
      debugPrint('Unable to load notification enrollments: $error');
    }
  }

  void _replaceEnrollmentIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _enrolledClassIds
      ..clear()
      ..addAll(
        docs
            .where((doc) => doc.data()['active'] != false)
            .map((doc) => doc.data()['class_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
  }

  Future<void> _checkActiveSessions() async {
    if (_checkingSessions || _enrolledClassIds.isEmpty) {
      return;
    }

    _checkingSessions = true;

    try {
      final snapshot = await _firestore
          .collection('attendance_sessions')
          .where('active', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        await _processSessionDocument(doc);
      }
    } catch (error) {
      debugPrint('Unable to check active attendance sessions: $error');
    } finally {
      _checkingSessions = false;
    }
  }

  Future<void> _processSessionDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_notifiedSessionIds.contains(doc.id)) {
      return;
    }

    final data = doc.data();

    if (data == null) {
      return;
    }

    if (!SessionTimeService.isOpen(data)) {
      return;
    }

    final classId = data['class_id']?.toString() ?? '';

    if (classId.isEmpty || !_enrolledClassIds.contains(classId)) {
      return;
    }

    final notice = AttendanceSessionNotice(
      sessionId: doc.id,
      classId: classId,
      subjectCode: data['subject_code']?.toString() ?? '',
      subjectName: data['subject_name']?.toString() ?? '',
      section: data['section']?.toString() ?? '',
    );

    _notifiedSessionIds.add(doc.id);

    final uid = _initializedUid;
    if (uid != null) {
      await _rememberSessions(uid);
    }

    if (!_noticeController.isClosed) {
      _noticeController.add(notice);
    }
  }

  Future<void> _loadRememberedSessions(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(_preferenceKey(uid)) ?? const <String>[];

    _notifiedSessionIds.addAll(saved);
  }

  Future<void> _rememberSessions(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    // Prevent the preference list from growing forever.
    final sessions = _notifiedSessionIds.toList();

    final trimmed = sessions.length <= 100
        ? sessions
        : sessions.sublist(sessions.length - 100);

    await prefs.setStringList(_preferenceKey(uid), trimmed);
  }

  String _preferenceKey(String uid) => 'mscas_attendance_notices_$uid';

  /// Kept for compatibility with the current Student dashboard logout flow.
  /// There is no FCM token anymore; this simply stops the Firestore listeners.
  Future<void> removeCurrentToken() async {
    await _cancelFirestoreListeners();

    _initializedUid = null;
    _enrolledClassIds.clear();
    _notifiedSessionIds.clear();
  }

  Future<void> _cancelFirestoreListeners() async {
    await _enrollmentSubscription?.cancel();
    await _sessionSubscription?.cancel();

    _enrollmentSubscription = null;
    _sessionSubscription = null;
  }

  Future<void> dispose() async {
    await removeCurrentToken();

    if (!_noticeController.isClosed) {
      await _noticeController.close();
    }
  }
}
