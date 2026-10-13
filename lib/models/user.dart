class User {
  final String? userId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? token;
  final String? studentNumber;
  final String? course;
  final int? yearLevel;

  User({
    this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.token,
    this.studentNumber,
    this.course,
    this.yearLevel,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id']?.toString(),
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      token: json['token']?.toString(),
      studentNumber: json['student_number']?.toString(),
      course: json['course']?.toString(),
      yearLevel: (json['year_level'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'student_number': studentNumber,
      'course': course,
      'year_level': yearLevel,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
}

class Class {
  final String classId;
  final String classCode;
  final String className;
  final String courseCode;
  final String semester;
  final String schoolYear;
  final String? room;
  final double? latitude;
  final double? longitude;
  final int? radiusMeters;
  final bool isActive;
  final String instructorName;
  final String instructorId;
  final String section;
  final String scheduleDay;
  final String startTime;
  final String endTime;
  final bool hasActiveSession;
  final String? activeSessionId;
  final DateTime? activeSessionEndAt;
  final List<Schedule>? schedules;

  Class({
    required this.classId,
    required this.classCode,
    required this.className,
    required this.courseCode,
    required this.semester,
    required this.schoolYear,
    this.room,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    required this.isActive,
    required this.instructorName,
    this.instructorId = '',
    this.section = '',
    this.scheduleDay = '',
    this.startTime = '',
    this.endTime = '',
    this.hasActiveSession = false,
    this.activeSessionId,
    this.activeSessionEndAt,
    this.schedules,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      classId: json['class_id']?.toString() ?? '',
      classCode:
          json['subject_code']?.toString() ??
          json['class_code']?.toString() ??
          '',
      className:
          json['subject_name']?.toString() ??
          json['class_name']?.toString() ??
          '',
      courseCode: json['course_code']?.toString() ?? '',
      semester: json['semester']?.toString() ?? '',
      schoolYear: json['school_year']?.toString() ?? '',
      room: json['room']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusMeters:
          (json['radius_m'] as num?)?.toInt() ??
          (json['radius_meters'] as num?)?.toInt() ??
          30,
      isActive: json['active'] is bool
          ? json['active'] as bool
          : (json['is_active'] is bool ? json['is_active'] as bool : true),
      instructorName: json['instructor_name']?.toString() ?? '',
      instructorId: json['instructor_id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      scheduleDay: json['schedule_day']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      hasActiveSession: json['has_active_session'] == true,
      activeSessionId: json['active_session_id']?.toString(),
      activeSessionEndAt: DateTime.tryParse(
        json['active_session_end_at']?.toString() ?? '',
      ),
      schedules: const [],
    );
  }

  String get scheduleText {
    final parts = <String>[
      if (scheduleDay.trim().isNotEmpty) scheduleDay.trim(),
      if (startTime.trim().isNotEmpty || endTime.trim().isNotEmpty)
        '${startTime.trim()} - ${endTime.trim()}'.trim(),
    ];
    return parts.join(' • ');
  }
}

class Schedule {
  final int scheduleId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  Schedule({
    required this.scheduleId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      scheduleId: (json['schedule_id'] as num?)?.toInt() ?? 0,
      dayOfWeek: json['day_of_week']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
    );
  }

  String get timeRange => '$startTime - $endTime';
}

class AttendanceRecord {
  final String attendanceId;
  final String studentId;
  final String classId;
  final String attendanceDate;
  final String checkInTime;
  final String status;
  final String verificationMethod;
  final double? faceConfidence;
  final bool isWithinGeofence;
  final String? className;
  final String? classCode;
  final String? section;

  AttendanceRecord({
    required this.attendanceId,
    required this.studentId,
    required this.classId,
    required this.attendanceDate,
    required this.checkInTime,
    required this.status,
    required this.verificationMethod,
    this.faceConfidence,
    required this.isWithinGeofence,
    this.className,
    this.classCode,
    this.section,
  });
}
