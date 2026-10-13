import 'supabase_auth_compat.dart';
import 'supabase_firestore_compat.dart';

class EnrollmentNotice {
  const EnrollmentNotice({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.subjectCode,
    required this.subjectName,
    required this.section,
    required this.message,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String classId;
  final String subjectCode;
  final String subjectName;
  final String section;
  final String message;
  final bool read;
  final DateTime? createdAt;

  factory EnrollmentNotice.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawCreatedAt = data['created_at'];
    DateTime? createdAt;
    if (rawCreatedAt is Timestamp) createdAt = rawCreatedAt.toDate();
    if (rawCreatedAt is DateTime) createdAt = rawCreatedAt;
    return EnrollmentNotice(
      id: doc.id,
      studentId: data['student_id']?.toString() ?? '',
      classId: data['class_id']?.toString() ?? '',
      subjectCode: data['subject_code']?.toString() ?? '',
      subjectName: data['subject_name']?.toString() ?? '',
      section: data['section']?.toString() ?? '',
      message: data['message']?.toString() ?? 'You were enrolled in a class.',
      read: data['read'] == true,
      createdAt: createdAt,
    );
  }
}

class EnrollmentNotificationService {
  EnrollmentNotificationService._();

  static final EnrollmentNotificationService instance =
      EnrollmentNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<EnrollmentNotice>> watchMine() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const Stream.empty();
    return _firestore
        .collection('notifications')
        .where('student_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final notices = snapshot.docs
              .map(EnrollmentNotice.fromDocument)
              .toList(growable: false);
          notices.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return notices;
        });
  }

  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || notificationId.isEmpty) return;
    final ref = _firestore.collection('notifications').doc(notificationId);
    final doc = await ref.get();
    final data = doc.data();
    if (data == null || data['student_id']?.toString() != uid) return;
    await ref.update({
      'read': true,
      'read_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final snapshot = await _firestore
        .collection('notifications')
        .where('student_id', isEqualTo: uid)
        .get();
    for (final doc in snapshot.docs) {
      if (doc.data()['read'] == true) continue;
      await doc.reference.update({
        'read': true,
        'read_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> createForEnrollment(
    Map<String, dynamic> enrollment,
  ) async {
    final studentId = enrollment['student_id']?.toString() ?? '';
    final classId = enrollment['class_id']?.toString() ?? '';
    if (studentId.isEmpty || classId.isEmpty) return;

    final code = enrollment['subject_code']?.toString() ?? '';
    final name = enrollment['subject_name']?.toString() ?? '';
    final section = enrollment['section']?.toString() ?? '';
    final subject = [
      if (code.trim().isNotEmpty) code.trim(),
      if (name.trim().isNotEmpty) name.trim(),
    ].join(' - ');
    final label = subject.isEmpty ? 'a class' : subject;
    final message = section.trim().isEmpty
        ? 'You have been enrolled in $label.'
        : 'You have been enrolled in $label (${section.trim()}).';

    final ref = FirebaseFirestore.instance
        .collection('notifications')
        .doc('enrollment_${studentId}_$classId');
    final existing = await ref.get();
    if (existing.exists) return;

    await ref.set({
      'type': 'enrollment',
      'student_id': studentId,
      'class_id': classId,
      'subject_code': code,
      'subject_name': name,
      'section': section,
      'message': message,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> createForEnrollments(
    Iterable<Map<String, dynamic>> enrollments,
  ) async {
    for (final enrollment in enrollments) {
      await createForEnrollment(enrollment);
    }
  }
}
