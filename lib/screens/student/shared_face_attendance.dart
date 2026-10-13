import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/location_service.dart';
import '../../widgets/camera_preview_surface.dart';

class SharedFaceAttendance extends StatefulWidget {
  const SharedFaceAttendance({super.key});

  @override
  State<SharedFaceAttendance> createState() => _SharedFaceAttendanceState();
}

class _SharedFaceAttendanceState extends State<SharedFaceAttendance> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final AttendanceService _attendanceService = AttendanceService();
  final LocationService _locationService = LocationService();

  CameraController? _controller;
  Timer? _scanTimer;

  bool _cameraReady = false;
  bool _processing = false;
  bool _submittingAttendance = false;
  bool _loadingCandidates = false;

  String _status = 'Preparing automatic face recognition...';

  EligibleFaceCandidateSet? _candidateSet;
  String? _candidateStudentId;
  String? _candidateName;
  int _candidateMatches = 0;
  int _missedFrames = 0;

  static const int _requiredMatches = 3;
  static const Duration _cacheLifetime = Duration(seconds: 60);
  final Map<String, DateTime> _recentlyProcessed = <String, DateTime>{};

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      CameraDescription selected = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selected = camera;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _cameraReady = true;
        _status = 'Loading students eligible for active attendance...';
      });

      await _refreshCandidateCache(force: true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      _startAutomaticScanning();
      unawaited(_scanFace());
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Camera unavailable.');
      Fluttertoast.showToast(
        msg: 'Camera error: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _refreshCandidateCache({bool force = false}) async {
    if (_loadingCandidates) return;

    final current = _candidateSet;
    if (!force &&
        current != null &&
        DateTime.now().difference(current.loadedAt) < _cacheLifetime) {
      return;
    }

    _loadingCandidates = true;
    try {
      final loaded = await _faceService.loadEligibleCandidates();
      _candidateSet = loaded;
      if (mounted) {
        setState(() {
          _status = loaded.isEmpty
              ? 'No registered students are eligible for an active attendance session.'
              : 'Ready • ${loaded.length} eligible registered student(s). Look normally at the camera.';
        });
      }
    } finally {
      _loadingCandidates = false;
    }
  }

  void _startAutomaticScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 950),
      (_) => _scanFace(),
    );
  }

  Future<void> _scanFace() async {
    if (_processing ||
        _submittingAttendance ||
        _loadingCandidates ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    _processing = true;

    try {
      await _refreshCandidateCache();
      final candidates = _candidateSet;
      if (candidates == null || candidates.isEmpty) {
        _resetCandidate();
        return;
      }

      final photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();

      final capture = await _faceService.analyzeSingleFace(
        bytes,
        maxYaw: 24,
        maxPitch: 22,
        maxRoll: 20,
      );

      final match = _faceService.identifyFromCandidateSet(
        capture.embedding,
        candidates,
      );

      final candidate = candidates.candidates[match.studentId];
      if (candidate == null) {
        _registerMiss();
        return;
      }

      final cooldownUntil = _recentlyProcessed[match.studentId];
      if (cooldownUntil != null && DateTime.now().isBefore(cooldownUntil)) {
        _resetCandidate();
        if (mounted) {
          setState(() {
            _status =
                '${candidate.displayName} was just processed. Waiting for the next student...';
          });
        }
        return;
      }

      _missedFrames = 0;

      if (_candidateStudentId == match.studentId) {
        _candidateMatches++;
      } else {
        _candidateStudentId = match.studentId;
        _candidateName = candidate.displayName;
        _candidateMatches = 1;
      }

      if (mounted) {
        setState(() {
          _status = _candidateMatches < _requiredMatches
              ? 'Verifying ${_candidateName ?? 'student'} • $_candidateMatches/$_requiredMatches — hold still'
              : 'Confirmed: ${_candidateName ?? 'Registered Student'}';
        });
      }

      if (_candidateMatches < _requiredMatches) return;

      _submittingAttendance = true;
      _scanTimer?.cancel();

      await _continueAttendance(
        studentId: match.studentId,
        studentName: _candidateName ?? candidate.displayName,
        confidence: match.similarity,
      );
    } catch (_) {
      _registerMiss();
    } finally {
      _processing = false;
    }
  }

  void _registerMiss() {
    _missedFrames++;
    if (_missedFrames >= 2) {
      _resetCandidate();
      if (mounted && !_submittingAttendance) {
        setState(() {
          _status = 'Looking for one clear registered student face...';
        });
      }
    }
  }

  Future<void> _continueAttendance({
    required String studentId,
    required String studentName,
    required double confidence,
  }) async {
    try {
      final classes = await _attendanceService.getStudentClasses(studentId);
      final activeClasses = classes
          .where((item) => item.hasActiveSession)
          .toList();

      if (activeClasses.isEmpty) {
        throw StateError('$studentName has no active attendance session.');
      }

      Class? selectedClass;
      if (activeClasses.length == 1) {
        selectedClass = activeClasses.first;
      } else {
        selectedClass = await _chooseActiveClass(activeClasses, studentName);
      }

      if (selectedClass == null) {
        _restartForNextScan();
        return;
      }

      if (mounted) {
        setState(() {
          _status = 'Confirmed $studentName • checking classroom location...';
        });
      }

      final position = await _validateLocation(selectedClass);

      await _attendanceService.markRecognizedFaceAttendance(
        recognizedStudentId: studentId,
        classObj: selectedClass,
        latitude: position.$1,
        longitude: position.$2,
        confidence: confidence,
      );

      _recentlyProcessed[studentId] = DateTime.now().add(
        const Duration(seconds: 45),
      );

      if (mounted) {
        setState(() {
          _status = '$studentName attendance recorded successfully.';
        });
      }

      Fluttertoast.showToast(
        msg: '$studentName attendance recorded.',
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) _restartForNextScan();
    } catch (e) {
      final message = e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('StateError: ', '');

      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );

      if (mounted) _restartForNextScan();
    }
  }

  Future<Class?> _chooseActiveClass(List<Class> classes, String studentName) {
    return showDialog<Class>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$studentName — Choose Active Class'),
          content: SizedBox(
            width: 500,
            child: ListView(
              shrinkWrap: true,
              children: classes.map((item) {
                return ListTile(
                  leading: const Icon(Icons.class_rounded),
                  title: Text('${item.classCode} - ${item.className}'),
                  subtitle: Text('${item.section} • ${item.room ?? 'No room'}'),
                  onTap: () => Navigator.pop(dialogContext, item),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<(double, double)> _validateLocation(Class classObj) async {
    final enabled = await _locationService.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Turn on GPS/Location services before continuing.');
    }

    final permission = await _locationService.hasPermission();
    if (!permission) {
      throw StateError('Location permission is required for attendance.');
    }

    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      throw StateError('Unable to determine the phone location.');
    }

    if (classObj.latitude == null || classObj.longitude == null) {
      throw StateError(
        'The administrator has not configured this classroom geofence.',
      );
    }

    final inside = await _locationService.isWithinGeofence(
      userLatitude: position.latitude,
      userLongitude: position.longitude,
      classroomLatitude: classObj.latitude!,
      classroomLongitude: classObj.longitude!,
      radiusMeters: classObj.radiusMeters ?? 30,
    );

    if (!inside) {
      throw StateError(
        'The phone is outside the allowed classroom attendance area.',
      );
    }

    return (position.latitude, position.longitude);
  }

  void _resetCandidate() {
    _candidateStudentId = null;
    _candidateName = null;
    _candidateMatches = 0;
    _missedFrames = 0;
  }

  void _restartForNextScan() {
    _resetCandidate();
    _submittingAttendance = false;
    if (mounted) {
      setState(() {
        final count = _candidateSet?.length ?? 0;
        _status = count == 0
            ? 'No eligible registered students right now.'
            : 'Ready • $count eligible registered student(s). Look normally at the camera.';
      });
    }
    _startAutomaticScanning();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.face_retouching_natural_rounded,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Automatic Shared Face Recognition — no button and no movement challenge. MSCAS confirms the same eligible student across multiple clear frames before attendance.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: !_cameraReady || _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreviewSurface(
                      controller: _controller!,
                      fit: BoxFit.contain,
                    ),
                    IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = math.min(
                            constraints.maxWidth * 0.66,
                            280.0,
                          );
                          return Center(
                            child: Container(
                              width: width,
                              height: width * 1.28,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _candidateMatches > 0
                                      ? Colors.greenAccent
                                      : Colors.white,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(width / 2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    if (_processing ||
                        _submittingAttendance ||
                        _loadingCandidates)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
