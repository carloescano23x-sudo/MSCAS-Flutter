import 'supabase_firestore_compat.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/user.dart';
import 'firebase_service.dart';
import 'session_time_service.dart';
import 'offline_attendance_service.dart';

class AttendanceService {
  final FirebaseService _firebase = FirebaseService();
  final OfflineAttendanceService _offline = OfflineAttendanceService.instance;

  Future<List<Class>> getStudentClasses(String studentId) async {
    final connection = await Connectivity().checkConnectivity();
    if (connection == ConnectivityResult.none) {
      return _offline.loadCachedClasses(studentId);
    }

    try {
      final enrollmentSnapshot = await _firebase.enrollments
          .where('student_id', isEqualTo: studentId)
          .get();

      final result = <Class>[];

      for (final enrollmentDoc in enrollmentSnapshot.docs) {
        final enrollment = enrollmentDoc.data();
        if (enrollment['active'] == false) continue;

        final classId = enrollment['class_id']?.toString() ?? '';
        if (classId.isEmpty) continue;

        final classDoc = await _firebase.classes.doc(classId).get();
        if (!classDoc.exists) continue;

        final classData = classDoc.data() ?? <String, dynamic>{};

        final sessionSnapshot = await _firebase.attendanceSessions
            .where('class_id', isEqualTo: classId)
            .where('active', isEqualTo: true)
            .get();

        final openSessions = sessionSnapshot.docs
            .where((doc) => SessionTimeService.isOpen(doc.data()))
            .toList();

        double? latitude;
        double? longitude;
        int radius = 30;

        final classroomId = classData['classroom_id']?.toString() ?? '';

        String room =
            classData['classroom_name']?.toString() ??
            classData['room']?.toString() ??
            '';

        Map<String, dynamic>? classroomData;

        // Preferred relationship: the Admin-selected classroom document ID.
        if (classroomId.isNotEmpty) {
          final classroomDocument = await _firebase.classrooms
              .doc(classroomId)
              .get();

          if (classroomDocument.exists) {
            classroomData = classroomDocument.data();
          }
        }

        // Compatibility for classes created before classroom_id existed.
        if (classroomData == null && room.isNotEmpty) {
          final classroomSnapshot = await _firebase.classrooms
              .where('name', isEqualTo: room)
              .limit(1)
              .get();

          if (classroomSnapshot.docs.isNotEmpty) {
            classroomData = classroomSnapshot.docs.first.data();
          }
        }

        if (classroomData != null && classroomData['active'] != false) {
          room = classroomData['name']?.toString() ?? room;
          latitude = (classroomData['latitude'] as num?)?.toDouble();
          longitude = (classroomData['longitude'] as num?)?.toDouble();
          radius = (classroomData['radius_m'] as num?)?.round() ?? 30;
        }

        result.add(
          Class(
            classId: classId,
            classCode: classData['subject_code']?.toString() ?? '',
            className: classData['subject_name']?.toString() ?? '',
            courseCode: enrollment['course']?.toString() ?? '',
            semester: classData['semester']?.toString() ?? '',
            schoolYear: '',
            room: room,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radius,
            isActive: classData['active'] is bool
                ? classData['active'] as bool
                : true,
            instructorName: classData['instructor_name']?.toString() ?? '',
            instructorId: classData['instructor_id']?.toString() ?? '',
            section: classData['section']?.toString() ?? '',
            scheduleDay: classData['schedule_day']?.toString() ?? '',
            startTime: classData['start_time']?.toString() ?? '',
            endTime: classData['end_time']?.toString() ?? '',
            hasActiveSession: openSessions.isNotEmpty,
            activeSessionId: openSessions.isEmpty
                ? null
                : openSessions.first.id,
            activeSessionEndAt: openSessions.isEmpty
                ? null
                : SessionTimeService.effectiveEnd(openSessions.first.data()),
          ),
        );
      }

      result.sort((a, b) => a.classCode.compareTo(b.classCode));

      await _offline.cacheClasses(studentId, result);
      return result;
    } catch (_) {
      final cached = await _offline.loadCachedClasses(studentId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<bool> hasActiveSession(String classId) async {
    final studentId = _firebase.currentUser?.id ?? '';

    final connection = await Connectivity().checkConnectivity();

    if (connection == ConnectivityResult.none) {
      return (await _offline.cachedActiveSessionId(
            studentId: studentId,
            classId: classId,
          )) !=
          null;
    }

    try {
      final snapshot = await _firebase.attendanceSessions
          .where('class_id', isEqualTo: classId)
          .where('active', isEqualTo: true)
          .get();

      return snapshot.docs.any((doc) => SessionTimeService.isOpen(doc.data()));
    } catch (_) {
      return (await _offline.cachedActiveSessionId(
            studentId: studentId,
            classId: classId,
          )) !=
          null;
    }
  }

  Future<String?> getActiveSessionId(String classId) async {
    final studentId = _firebase.currentUser?.id ?? '';

    final connection = await Connectivity().checkConnectivity();

    if (connection == ConnectivityResult.none) {
      return _offline.cachedActiveSessionId(
        studentId: studentId,
        classId: classId,
      );
    }

    try {
      final snapshot = await _firebase.attendanceSessions
          .where('class_id', isEqualTo: classId)
          .where('active', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        if (SessionTimeService.isOpen(doc.data())) return doc.id;
      }
    } catch (_) {}

    return _offline.cachedActiveSessionId(
      studentId: studentId,
      classId: classId,
    );
  }

  Future<void> markAttendancePin({
    required String studentId,
    required Class classObj,
    required String pin,
    required double latitude,
    required double longitude,
  }) async {
    final connection = await Connectivity().checkConnectivity();

    if (connection == ConnectivityResult.none) {
      throw StateError(
        'PIN attendance requires an internet connection. Use face attendance offline if this session was previously synchronized.',
      );
    }

    final sessionId = await getActiveSessionId(classObj.classId);

    if (sessionId == null) {
      throw StateError(
        'Your instructor has not opened attendance for this class.',
      );
    }

    final pinSnapshot = await _firebase.pinSessions
        .where('class_id', isEqualTo: classObj.classId)
        .where('pin', isEqualTo: pin)
        .where('active', isEqualTo: true)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? validPin;

    for (final document in pinSnapshot.docs) {
      final expiresAt = document.data()['expires_at'];

      if (expiresAt is Timestamp &&
          expiresAt.toDate().isAfter(DateTime.now())) {
        validPin = document;
        break;
      }
    }

    if (validPin == null) {
      throw StateError('The PIN is invalid or has expired.');
    }

    await _createAttendance(
      studentId: studentId,
      classObj: classObj,
      sessionId: sessionId,
      latitude: latitude,
      longitude: longitude,
      method: 'pin',
      verified: true,
      sourceDeviceUserId: _firebase.currentUser?.id,
    );
  }

  /// Use this after the face engine returns a recognized student UID.
  ///
  /// [recognizedStudentId] is intentionally separate from the currently
  /// logged-in Firebase user so a student may use a classmate's phone.
  /// Returns true when attendance was saved locally and is waiting to sync.
  Future<bool> markRecognizedFaceAttendance({
    required String recognizedStudentId,
    required Class classObj,
    required double latitude,
    required double longitude,
    required double confidence,
  }) async {
    final currentUid = _firebase.currentUser?.id ?? '';

    final connection = await Connectivity().checkConnectivity();

    if (connection == ConnectivityResult.none) {
      if (currentUid != recognizedStudentId) {
        throw StateError(
          'Shared-device attendance requires an internet connection.',
        );
      }

      final sessionId =
          classObj.activeSessionId ??
          await _offline.cachedActiveSessionId(
            studentId: recognizedStudentId,
            classId: classObj.classId,
          );

      if (sessionId == null) {
        throw StateError(
          'No previously synchronized active attendance session is available for offline use.',
        );
      }

      await _offline.queueFaceAttendance(
        studentId: recognizedStudentId,
        classObj: classObj,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        confidence: confidence,
      );

      return true;
    }

    try {
      final sessionId = await getActiveSessionId(classObj.classId);

      if (sessionId == null) {
        throw StateError(
          'The instructor has not opened attendance for this class.',
        );
      }

      final enrolled = await _firebase.enrollments
          .where('student_id', isEqualTo: recognizedStudentId)
          .where('class_id', isEqualTo: classObj.classId)
          .limit(1)
          .get();

      final activeEnrollment = enrolled.docs.any(
        (doc) => doc.data()['active'] != false,
      );

      if (!activeEnrollment) {
        throw StateError(
          'The recognized student is not actively enrolled in this class.',
        );
      }

      await _createAttendance(
        studentId: recognizedStudentId,
        classObj: classObj,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        method: 'face',
        verified: true,
        confidence: confidence,
        sourceDeviceUserId: _firebase.currentUser?.id,
      );

      return false;
    } on FirebaseException catch (error) {
      // If connectivity disappeared after the initial check, queue only the
      // logged-in student's own face attendance.
      if (currentUid == recognizedStudentId &&
          (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
        final sessionId =
            classObj.activeSessionId ??
            await _offline.cachedActiveSessionId(
              studentId: recognizedStudentId,
              classId: classObj.classId,
            );

        if (sessionId != null) {
          await _offline.queueFaceAttendance(
            studentId: recognizedStudentId,
            classObj: classObj,
            sessionId: sessionId,
            latitude: latitude,
            longitude: longitude,
            confidence: confidence,
          );
          return true;
        }
      }

      rethrow;
    }
  }

  Future<void> _createAttendance({
    required String studentId,
    required Class classObj,
    required String sessionId,
    required double latitude,
    required double longitude,
    required String method,
    required bool verified,
    String? sourceDeviceUserId,
    double? confidence,
  }) async {
    final enrollmentSnapshot = await _firebase.enrollments
        .where('student_id', isEqualTo: studentId)
        .where('class_id', isEqualTo: classObj.classId)
        .limit(10)
        .get();

    final hasActiveEnrollment = enrollmentSnapshot.docs.any(
      (doc) => doc.data()['active'] != false,
    );

    if (!hasActiveEnrollment) {
      throw StateError('This student is not actively enrolled in this class.');
    }

    final attendanceId = '${sessionId}_$studentId';
    final attendanceRef = _firebase.attendance.doc(attendanceId);
    final sessionRef = _firebase.attendanceSessions.doc(sessionId);
    final userRef = _firebase.users.doc(studentId);

    try {
      await _firebase.firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction.get(sessionRef);

        final sessionData = sessionDoc.data();
        if (!sessionDoc.exists ||
            sessionData == null ||
            !SessionTimeService.isOpen(sessionData)) {
          throw StateError(
            'The attendance session is closed or its allowed time has ended.',
          );
        }

        // IMPORTANT FOR SHARED-DEVICE ATTENDANCE:
        //
        // Do NOT read attendanceRef here.
        // When Student A's phone recognizes Student B, Firestore correctly
        // prevents Student A from reading Student B's attendance history.
        //
        // Duplicate protection is still enforced by the deterministic
        // document ID: sessionId_studentId.
        // - If it does not exist, this transaction is a CREATE and is allowed.
        // - If it already exists, this becomes an UPDATE and Firestore rules
        //   reject it because students cannot update attendance records.
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data() ?? <String, dynamic>{};

        if (!userDoc.exists || userData['active'] == false) {
          throw StateError('The student account is unavailable or inactive.');
        }

        final studentName =
            '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                .trim();

        final now = DateTime.now();

        final date =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final hour = now.hour.toString().padLeft(2, '0');
        final minute = now.minute.toString().padLeft(2, '0');

        transaction.set(attendanceRef, {
          'student_id': studentId,
          'student_name': studentName,
          'student_email': userData['email']?.toString() ?? '',
          'student_number': userData['student_number']?.toString() ?? '',
          'class_id': classObj.classId,
          'session_id': sessionId,
          'subject_code': classObj.classCode,
          'subject_name': classObj.className,
          'section': classObj.section,
          'instructor_id': classObj.instructorId,
          'instructor_name': classObj.instructorName,
          'status': 'present',
          'verification_method': method,
          'method': method,
          'verified': verified,
          'confidence': confidence,
          'latitude': latitude,
          'longitude': longitude,
          'source_device_user_id': sourceDeviceUserId,
          'recognized_student_id': studentId,
          'date': date,
          'time': '$hour:$minute',
          'timestamp': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      // The deterministic ID makes a duplicate submission target the same
      // attendance document. Students cannot update attendance records, so a
      // duplicate can surface as permission-denied. Keep the message clear.
      if (error.code == 'permission-denied') {
        throw StateError(
          'Attendance was not recorded. This student may already be marked present for this session.',
        );
      }

      rethrow;
    }
  }

  Future<List<AttendanceRecord>> getAttendanceHistory(String studentId) async {
    final snapshot = await _firebase.attendance
        .where('student_id', isEqualTo: studentId)
        .get();

    final records = snapshot.docs.map((doc) {
      final data = doc.data();
      final timestamp = data['timestamp'];

      String date = data['date']?.toString() ?? '';
      String time = data['time']?.toString() ?? '';

      if (timestamp is Timestamp) {
        final value = timestamp.toDate();

        date =
            '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

        final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

        final minute = value.minute.toString().padLeft(2, '0');

        final period = value.hour >= 12 ? 'PM' : 'AM';

        time = '$hour:$minute $period';
      }

      return AttendanceRecord(
        attendanceId: doc.id,
        studentId: data['student_id']?.toString() ?? '',
        classId: data['class_id']?.toString() ?? '',
        attendanceDate: date,
        checkInTime: time,
        status: data['status']?.toString() ?? 'present',
        verificationMethod:
            data['verification_method']?.toString() ??
            data['method']?.toString() ??
            '',
        faceConfidence: (data['confidence'] as num?)?.toDouble(),
        isWithinGeofence: true,
        className: data['subject_name']?.toString(),
        classCode: data['subject_code']?.toString(),
        section: data['section']?.toString(),
      );
    }).toList();

    records.sort((a, b) {
      final byDate = b.attendanceDate.compareTo(a.attendanceDate);

      if (byDate != 0) return byDate;

      return b.checkInTime.compareTo(a.checkInTime);
    });

    return records;
  }
}
