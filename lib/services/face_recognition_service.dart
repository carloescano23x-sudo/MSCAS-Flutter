import 'dart:math';
import 'dart:typed_data';

import 'supabase_firestore_compat.dart';
import 'package:face_plugin/face_plugin.dart';

import 'firebase_service.dart';
import 'session_time_service.dart';

class FaceMatchResult {
  final String studentId;
  final double similarity;

  const FaceMatchResult({required this.studentId, required this.similarity});
}

class FaceCaptureAnalysis {
  final Face face;
  final List<double> embedding;
  final double areaRatio;

  const FaceCaptureAnalysis({
    required this.face,
    required this.embedding,
    required this.areaRatio,
  });
}

class EligibleFaceCandidate {
  final String studentId;
  final String displayName;
  final List<List<double>> templates;

  const EligibleFaceCandidate({
    required this.studentId,
    required this.displayName,
    required this.templates,
  });
}

class EligibleFaceCandidateSet {
  final Map<String, EligibleFaceCandidate> candidates;
  final DateTime loadedAt;

  const EligibleFaceCandidateSet({
    required this.candidates,
    required this.loadedAt,
  });

  int get length => candidates.length;
  bool get isEmpty => candidates.isEmpty;
}

class FaceRecognitionService {
  final FirebaseService _firebase = FirebaseService();

  static const double registrationMinFaceScore = 0.60;
  static const int registrationMinLandmarks = 4;

  // face_plugin documents 0.50 as a recommended same-person starting point.
  // We combine it with candidate-gap and repeated-frame confirmation.
  static const double matchThreshold = 0.50;
  static const double minimumBestMatchGap = 0.03;
  static const double sharedMatchThreshold = 0.58;
  static const double sharedMinimumGap = 0.07;

  static const int requiredRegistrationSamples = 5;

  Future<FaceCaptureAnalysis> analyzeSingleFace(
    Uint8List jpegBytes, {
    double maxYaw = 30,
    double maxPitch = 28,
    double maxRoll = 24,
  }) async {
    final results = await Future.wait<dynamic>([
      FacePlugin.detectFaces(jpegBytes),
      FacePlugin.extractFeatures(jpegBytes),
    ]);

    final faces = results[0] as List<Face>;
    final features = results[1] as List<List<double>>;

    if (faces.isEmpty) {
      throw StateError('No face detected.');
    }

    if (faces.length != 1) {
      throw StateError('Only one face should be visible.');
    }

    if (features.length != faces.length || features.isEmpty) {
      throw StateError('Unable to extract a valid face template.');
    }

    final face = faces.first;

    if (face.landmarkCount < registrationMinLandmarks ||
        face.faceScore < registrationMinFaceScore) {
      throw StateError('Face quality is too low.');
    }

    final imageArea = face.width * face.height;
    final faceArea = face.bboxW * face.bboxH;
    final areaRatio = imageArea <= 0 ? 0.0 : faceArea / imageArea;

    if (areaRatio < 0.055) {
      throw StateError('Move a little closer to the camera.');
    }

    if (face.headEulerAngleY.abs() > maxYaw ||
        face.headEulerAngleX.abs() > maxPitch ||
        face.headEulerAngleZ.abs() > maxRoll) {
      throw StateError('Keep your face closer to the requested position.');
    }

    return FaceCaptureAnalysis(
      face: face,
      embedding: _normalize(features.first),
      areaRatio: areaRatio,
    );
  }

  Future<List<double>> extractSingleFaceEmbedding(Uint8List jpegBytes) async {
    final analysis = await analyzeSingleFace(jpegBytes);
    return analysis.embedding;
  }

  Future<void> saveRegistrationSamples({
    required String studentId,
    required List<List<double>> samples,
  }) async {
    if (samples.length < requiredRegistrationSamples) {
      throw StateError(
        '$requiredRegistrationSamples valid captures are required.',
      );
    }

    final normalized = samples.map((sample) => _normalize(sample)).toList();

    final averaged = _averageEmbeddings(normalized);

    if (averaged.isEmpty) {
      throw StateError('Unable to create the final face template.');
    }

    // Firestore does not support List<List<double>>, so samples are stored
    // as map values where each individual value is a normal number array.
    final templateMap = <String, dynamic>{};

    for (int i = 0; i < normalized.length; i++) {
      templateMap['sample_${i + 1}'] = normalized[i];
    }

    await _firebase.faceData.doc(studentId).set({
      'user_id': studentId,
      'templates': templateMap,
      'face_encoding': averaged,
      'embedding_dimension': averaged.length,
      'sample_count': normalized.length,
      'registered': true,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasRegisteredFace(String studentId) async {
    final document = await _firebase.faceData.doc(studentId).get();

    if (!document.exists) return false;

    final data = document.data();
    if (data == null) return false;

    final templates = data['templates'];
    final averaged = data['face_encoding'];

    return (templates is Map && templates.isNotEmpty) ||
        (templates is List && templates.isNotEmpty) ||
        (averaged is List && averaged.isNotEmpty);
  }

  Future<List<List<double>>> getStudentTemplates(String studentId) async {
    final document = await _firebase.faceData.doc(studentId).get();

    if (!document.exists) return const [];

    final data = document.data();
    if (data == null) return const [];

    final parsed = <List<double>>[];
    final templates = data['templates'];

    if (templates is Map) {
      final entries = templates.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

      for (final entry in entries) {
        final values = _parseNumberList(entry.value);
        if (values.isNotEmpty) {
          parsed.add(_normalize(values));
        }
      }
    } else if (templates is List) {
      // Compatibility with early experimental data.
      for (final raw in templates) {
        final values = _parseNumberList(raw);
        if (values.isNotEmpty) {
          parsed.add(_normalize(values));
        }
      }
    }

    if (parsed.isNotEmpty) return parsed;

    final averaged = _parseNumberList(data['face_encoding']);

    if (averaged.isNotEmpty) {
      return [_normalize(averaged)];
    }

    return const [];
  }

  Future<bool> verifyStudent({
    required String studentId,
    required List<double> probeEmbedding,
  }) async {
    final score = await studentSimilarity(
      studentId: studentId,
      probeEmbedding: probeEmbedding,
    );

    if (score < 0) {
      throw StateError(
        'No registered face was found. Register the face first.',
      );
    }

    return score >= matchThreshold;
  }

  Future<double> studentSimilarity({
    required String studentId,
    required List<double> probeEmbedding,
  }) async {
    final templates = await getStudentTemplates(studentId);

    if (templates.isEmpty) return -1;

    return _scoreCandidate(_normalize(probeEmbedding), templates);
  }

  Future<EligibleFaceCandidateSet> loadEligibleCandidates() async {
    final activeSessions = await _firebase.attendanceSessions
        .where('active', isEqualTo: true)
        .get();

    final activeClassIds = activeSessions.docs
        .where((doc) => SessionTimeService.isOpen(doc.data()))
        .map((doc) => doc.data()['class_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (activeClassIds.isEmpty) {
      return EligibleFaceCandidateSet(
        candidates: const <String, EligibleFaceCandidate>{},
        loadedAt: DateTime.now(),
      );
    }

    final studentIds = <String>{};
    for (final classId in activeClassIds) {
      final enrollments = await _firebase.enrollments
          .where('class_id', isEqualTo: classId)
          .get();
      for (final enrollment in enrollments.docs) {
        if (enrollment.data()['active'] == false) continue;
        final id = enrollment.data()['student_id']?.toString() ?? '';
        if (id.isNotEmpty) studentIds.add(id);
      }
    }

    final entries = await Future.wait(
      studentIds.map((studentId) async {
        final userDoc = await _firebase.users.doc(studentId).get();
        final user = userDoc.data();
        if (!userDoc.exists || user == null || user['active'] == false) {
          return null;
        }
        if (user['role']?.toString().trim().toLowerCase() != 'student') {
          return null;
        }
        final templates = await getStudentTemplates(studentId);
        if (templates.isEmpty) return null;
        final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
            .trim();
        return MapEntry(
          studentId,
          EligibleFaceCandidate(
            studentId: studentId,
            displayName: name.isEmpty ? 'Registered Student' : name,
            templates: templates,
          ),
        );
      }),
    );

    final candidates = <String, EligibleFaceCandidate>{};
    for (final entry in entries) {
      if (entry != null) candidates[entry.key] = entry.value;
    }

    return EligibleFaceCandidateSet(
      candidates: candidates,
      loadedAt: DateTime.now(),
    );
  }

  FaceMatchResult identifyFromCandidateSet(
    List<double> probeEmbedding,
    EligibleFaceCandidateSet candidateSet,
  ) {
    if (candidateSet.isEmpty) {
      throw StateError(
        'No registered students are eligible for open sessions.',
      );
    }

    final probe = _normalize(probeEmbedding);
    String? bestStudentId;
    double bestScore = -1;
    double secondBestScore = -1;

    for (final candidate in candidateSet.candidates.values) {
      final score = _scoreCandidate(probe, candidate.templates);
      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        bestStudentId = candidate.studentId;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestStudentId == null || bestScore < sharedMatchThreshold) {
      throw StateError('Face not recognized with enough confidence.');
    }
    if (secondBestScore >= 0 &&
        bestScore - secondBestScore < sharedMinimumGap) {
      throw StateError(
        'Face match is ambiguous. Please face the camera clearly.',
      );
    }
    return FaceMatchResult(studentId: bestStudentId, similarity: bestScore);
  }

  Future<FaceMatchResult> identifyEligibleStudent(
    List<double> probeEmbedding,
  ) async {
    final activeSessions = await _firebase.attendanceSessions
        .where('active', isEqualTo: true)
        .get();

    final openSessions = activeSessions.docs
        .where((doc) => SessionTimeService.isOpen(doc.data()))
        .toList();
    if (openSessions.isEmpty) {
      throw StateError('No attendance session is currently open.');
    }

    final activeClassIds = openSessions
        .map((doc) => doc.data()['class_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final candidateStudentIds = <String>{};

    for (final classId in activeClassIds) {
      final enrollments = await _firebase.enrollments
          .where('class_id', isEqualTo: classId)
          .get();

      for (final enrollment in enrollments.docs) {
        if (enrollment.data()['active'] == false) continue;

        final studentId = enrollment.data()['student_id']?.toString() ?? '';

        if (studentId.isNotEmpty) {
          candidateStudentIds.add(studentId);
        }
      }
    }

    if (candidateStudentIds.isEmpty) {
      throw StateError(
        'No enrolled students are eligible for the open sessions.',
      );
    }

    final probe = _normalize(probeEmbedding);

    String? bestStudentId;
    double bestScore = -1;
    double secondBestScore = -1;

    for (final studentId in candidateStudentIds) {
      final templates = await getStudentTemplates(studentId);
      if (templates.isEmpty) continue;

      final score = _scoreCandidate(probe, templates);

      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        bestStudentId = studentId;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestStudentId == null || bestScore < matchThreshold) {
      throw StateError('Face not recognized yet.');
    }

    if (secondBestScore >= 0 &&
        bestScore - secondBestScore < minimumBestMatchGap) {
      throw StateError('Face match is ambiguous.');
    }

    return FaceMatchResult(studentId: bestStudentId, similarity: bestScore);
  }

  double _scoreCandidate(List<double> probe, List<List<double>> templates) {
    final scores = <double>[];

    for (final template in templates) {
      if (template.length != probe.length) continue;

      final score = cosineSimilarity(probe, template);
      if (score >= -1) scores.add(score);
    }

    if (scores.isEmpty) return -1;

    scores.sort((a, b) => b.compareTo(a));

    if (scores.length == 1) {
      return scores.first;
    }

    // Strongest registration pose has most weight while a second supporting
    // pose helps keep recognition stable across small camera/lighting changes.
    return (scores[0] * 0.75) + (scores[1] * 0.25);
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) {
      return -1;
    }

    double dot = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return -1;

    return dot / (sqrt(normA) * sqrt(normB));
  }

  List<double> _parseNumberList(dynamic raw) {
    if (raw is! List) return const [];

    final result = <double>[];

    for (final value in raw) {
      if (value is num) result.add(value.toDouble());
    }

    return result;
  }

  List<double> _normalize(List<double> values) {
    double norm = 0;

    for (final value in values) {
      norm += value * value;
    }

    norm = sqrt(norm);

    if (norm == 0) {
      return List<double>.from(values);
    }

    return values.map((value) => value / norm).toList();
  }

  List<double> _averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return const [];

    final length = embeddings.first.length;
    final result = List<double>.filled(length, 0);

    int validCount = 0;

    for (final embedding in embeddings) {
      if (embedding.length != length) continue;

      for (int i = 0; i < length; i++) {
        result[i] += embedding[i];
      }

      validCount++;
    }

    if (validCount == 0) return const [];

    for (int i = 0; i < result.length; i++) {
      result[i] /= validCount;
    }

    return _normalize(result);
  }
}
