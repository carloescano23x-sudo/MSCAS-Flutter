import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_firestore_compat.dart';

/// Compatibility facade retained so the existing MSCAS feature code can be
/// migrated without changing every call site at once. The backend is Supabase.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final SupabaseClient supabase = Supabase.instance.client;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  User? get currentUser => supabase.auth.currentUser;

  CollectionReference<Map<String, dynamic>> get users =>
      firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get classes =>
      firestore.collection('classes');
  CollectionReference<Map<String, dynamic>> get enrollments =>
      firestore.collection('enrollments');
  CollectionReference<Map<String, dynamic>> get attendance =>
      firestore.collection('attendance');
  CollectionReference<Map<String, dynamic>> get attendanceSessions =>
      firestore.collection('attendance_sessions');
  CollectionReference<Map<String, dynamic>> get pinSessions =>
      firestore.collection('pin_sessions');
  CollectionReference<Map<String, dynamic>> get classrooms =>
      firestore.collection('classrooms');
  CollectionReference<Map<String, dynamic>> get faceData =>
      firestore.collection('face_data');

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) => supabase.auth.signUp(email: email, password: password);

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) => supabase.auth.signInWithPassword(email: email, password: password);

  Future<void> sendPasswordResetEmail(String email) =>
      supabase.auth.resetPasswordForEmail(email);

  Future<void> signOut() => supabase.auth.signOut();

  Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    String? studentNumber,
    String? course,
    int? yearLevel,
  }) async {
    await users.doc(uid).set({
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'active': true,
      'student_number': studentNumber,
      'course': course,
      'year_level': yearLevel,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFaceData(String uid, List<double> faceEncoding) async {
    await faceData.doc(uid).set({
      'user_id': uid,
      'face_encoding': faceEncoding,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<double>?> getFaceData(String uid) async {
    final doc = await faceData.doc(uid).get();
    if (!doc.exists) return null;
    final encoding = doc.data()?['face_encoding'];
    if (encoding is List) {
      return encoding.map((value) => (value as num).toDouble()).toList();
    }
    return null;
  }
}
