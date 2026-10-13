import 'dart:async';
import 'dart:convert';

import 'supabase_firestore_compat.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_auth_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class OfflineSyncNotice {
  final int synced;
  final int remaining;

  const OfflineSyncNotice({required this.synced, required this.remaining});
}

class OfflineAttendanceService {
  OfflineAttendanceService._();

  static final OfflineAttendanceService instance = OfflineAttendanceService._();

  static const String _pendingKey = 'mscas_pending_attendance_v1';
  static const String _classCachePrefix = 'mscas_class_cache_v1_';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  final StreamController<OfflineSyncNotice> _syncController =
      StreamController<OfflineSyncNotice>.broadcast();

  bool _syncing = false;

  Stream<OfflineSyncNotice> get syncNotices => _syncController.stream;

  Future<bool> hasNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  Future<void> startAutoSync() async {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      if (result != ConnectivityResult.none) {
        unawaited(syncPending());
      }
    });

    if (await hasNetwork()) {
      unawaited(syncPending());
    }
  }

  Future<void> stopAutoSync() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> cacheClasses(String studentId, List<Class> classes) async {
    if (studentId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    final encoded = classes
        .map((item) => jsonEncode(_classToMap(item)))
        .toList();

    await prefs.setStringList('$_classCachePrefix$studentId', encoded);
  }

  Future<List<Class>> loadCachedClasses(String studentId) async {
    if (studentId.isEmpty) {
      return const <Class>[];
    }

    final prefs = await SharedPreferences.getInstance();

    final encoded =
        prefs.getStringList('$_classCachePrefix$studentId') ?? const <String>[];

    final result = <Class>[];

    for (final raw in encoded) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        result.add(Class.fromJson(decoded));
      } catch (_) {}
    }

    return result;
  }

  Future<String?> cachedActiveSessionId({
    required String studentId,
    required String classId,
  }) async {
    final classes = await loadCachedClasses(studentId);

    for (final item in classes) {
      if (item.classId == classId &&
          item.hasActiveSession &&
          item.activeSessionId != null &&
          item.activeSessionId!.isNotEmpty &&
          (item.activeSessionEndAt == null ||
              DateTime.now().isBefore(item.activeSessionEndAt!))) {
        return item.activeSessionId;
      }
    }

    return null;
  }

  Future<void> queueFaceAttendance({
    required String studentId,
    required Class classObj,
    required String sessionId,
    required double latitude,
    required double longitude,
    required double confidence,
  }) async {
    final currentUid = _auth.currentUser?.uid ?? '';

    // Offline shared-device attendance is intentionally blocked. The app
    // cannot safely identify/authorize another student with stale server data.
    if (currentUid.isEmpty || currentUid != studentId) {
      throw StateError(
        'Shared-device attendance requires an internet connection.',
      );
    }

    if (!classObj.hasActiveSession || classObj.activeSessionId != sessionId) {
      throw StateError(
        'Offline attendance is only available for a session previously synchronized while it was active.',
      );
    }

    if (classObj.activeSessionEndAt != null &&
        !DateTime.now().isBefore(classObj.activeSessionEndAt!)) {
      throw StateError(
        'The attendance time ended. Reconnect to receive any instructor extension.',
      );
    }

    if (classObj.latitude == null || classObj.longitude == null) {
      throw StateError('This class does not have a cached classroom geofence.');
    }

    final now = DateTime.now();

    final pending = <String, dynamic>{
      'local_id': '${sessionId}_$studentId',
      'student_id': studentId,
      'class_id': classObj.classId,
      'session_id': sessionId,
      'subject_code': classObj.classCode,
      'subject_name': classObj.className,
      'section': classObj.section,
      'instructor_id': classObj.instructorId,
      'instructor_name': classObj.instructorName,
      'room': classObj.room ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'confidence': confidence,
      'verification_method': 'face',
      'captured_at': now.toIso8601String(),
      'source_device_user_id': currentUid,
      'sync_error': '',
    };

    final items = await _readPending();

    final duplicate = items.any(
      (item) => item['local_id']?.toString() == pending['local_id'],
    );

    if (duplicate) {
      throw StateError('Attendance is already pending sync for this session.');
    }

    items.add(pending);
    await _writePending(items);
  }

  Future<List<Map<String, dynamic>>> pendingForStudent(String studentId) async {
    final items = await _readPending();

    return items
        .where((item) => item['student_id']?.toString() == studentId)
        .toList();
  }

  Future<int> pendingCountForStudent(String studentId) async {
    return (await pendingForStudent(studentId)).length;
  }

  Future<void> syncPending() async {
    if (_syncing || !await hasNetwork()) {
      return;
    }

    final currentUid = _auth.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    _syncing = true;

    try {
      final items = await _readPending();
      if (items.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      int synced = 0;

      for (final item in items) {
        if (item['student_id']?.toString() != currentUid) {
          remaining.add(item);
          continue;
        }

        try {
          final success = await _syncOne(item);

          if (success) {
            synced++;
          } else {
            remaining.add(item);
          }
        } catch (error) {
          item['sync_error'] = error.toString();
          remaining.add(item);
        }
      }

      await _writePending(remaining);

      if (!_syncController.isClosed && synced > 0) {
        _syncController.add(
          OfflineSyncNotice(
            synced: synced,
            remaining: remaining
                .where((item) => item['student_id']?.toString() == currentUid)
                .length,
          ),
        );
      }
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _syncOne(Map<String, dynamic> item) async {
    final studentId = item['student_id']?.toString() ?? '';
    final sessionId = item['session_id']?.toString() ?? '';
    final classId = item['class_id']?.toString() ?? '';
    final sourceUid = item['source_device_user_id']?.toString() ?? '';

    if (studentId.isEmpty ||
        sessionId.isEmpty ||
        classId.isEmpty ||
        sourceUid != _auth.currentUser?.uid) {
      return false;
    }

    final attendanceId = '${sessionId}_$studentId';

    final attendanceRef = _firestore.collection('attendance').doc(attendanceId);

    // The student can read their own attendance. If it already exists,
    // treat the pending item as synchronized instead of duplicating it.
    final existing = await attendanceRef.get();

    if (existing.exists) {
      return true;
    }

    final enrollment = await _firestore
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .where('class_id', isEqualTo: classId)
        .get();

    final activelyEnrolled = enrollment.docs.any(
      (doc) => doc.data()['active'] != false,
    );

    if (!activelyEnrolled) {
      throw StateError('Enrollment is no longer active.');
    }

    final userDoc = await _firestore.collection('users').doc(studentId).get();

    final userData = userDoc.data() ?? <String, dynamic>{};

    if (!userDoc.exists || userData['active'] == false) {
      throw StateError('Student account is inactive.');
    }

    // Session must still exist, but it is allowed to be closed now:
    // the phone captured this attendance while its cached copy was active.
    final sessionDoc = await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) {
      throw StateError('Attendance session no longer exists.');
    }

    final capturedAt =
        DateTime.tryParse(item['captured_at']?.toString() ?? '') ??
        DateTime.now();

    final sessionData = sessionDoc.data() ?? <String, dynamic>{};
    final endValue =
        sessionData['effective_end_at'] ?? sessionData['scheduled_end_at'];
    final effectiveEnd = endValue is Timestamp ? endValue.toDate() : null;
    if (effectiveEnd != null && !capturedAt.isBefore(effectiveEnd)) {
      throw StateError(
        'Offline attendance was captured after the attendance window ended.',
      );
    }

    final date =
        '${capturedAt.year}-${capturedAt.month.toString().padLeft(2, '0')}-${capturedAt.day.toString().padLeft(2, '0')}';

    final time =
        '${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}';

    final studentName =
        '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim();

    await attendanceRef.set({
      'student_id': studentId,
      'student_name': studentName,
      'student_email': userData['email']?.toString() ?? '',
      'student_number': userData['student_number']?.toString() ?? '',
      'class_id': classId,
      'session_id': sessionId,
      'subject_code': item['subject_code']?.toString() ?? '',
      'subject_name': item['subject_name']?.toString() ?? '',
      'section': item['section']?.toString() ?? '',
      'instructor_id': item['instructor_id']?.toString() ?? '',
      'instructor_name': item['instructor_name']?.toString() ?? '',
      'status': 'present',
      'verification_method': 'face',
      'method': 'face',
      'verified': true,
      'confidence': (item['confidence'] as num?)?.toDouble(),
      'latitude': (item['latitude'] as num?)?.toDouble(),
      'longitude': (item['longitude'] as num?)?.toDouble(),
      'source_device_user_id': sourceUid,
      'recognized_student_id': studentId,
      'date': date,
      'time': time,
      'timestamp': Timestamp.fromDate(capturedAt),
      'captured_at_client': Timestamp.fromDate(capturedAt),
      'synced_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'offline_capture': true,
    });

    return true;
  }

  Future<List<Map<String, dynamic>>> _readPending() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = prefs.getStringList(_pendingKey) ?? const <String>[];

    final result = <Map<String, dynamic>>[];

    for (final raw in encoded) {
      try {
        result.add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }

    return result;
  }

  Future<void> _writePending(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_pendingKey, items.map(jsonEncode).toList());
  }

  Map<String, dynamic> _classToMap(Class item) {
    return {
      'class_id': item.classId,
      'subject_code': item.classCode,
      'subject_name': item.className,
      'course_code': item.courseCode,
      'semester': item.semester,
      'school_year': item.schoolYear,
      'room': item.room,
      'latitude': item.latitude,
      'longitude': item.longitude,
      'radius_meters': item.radiusMeters,
      'active': item.isActive,
      'instructor_name': item.instructorName,
      'instructor_id': item.instructorId,
      'section': item.section,
      'schedule_day': item.scheduleDay,
      'start_time': item.startTime,
      'end_time': item.endTime,
      'has_active_session': item.hasActiveSession,
      'active_session_id': item.activeSessionId,
      'active_session_end_at': item.activeSessionEndAt?.toIso8601String(),
    };
  }
}
