import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/face_liveness_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/location_service.dart';
import '../../widgets/camera_preview_surface.dart';

class AttendanceCamera extends StatefulWidget {
  final Class classObj;

  const AttendanceCamera({super.key, required this.classObj});

  @override
  State<AttendanceCamera> createState() => AttendanceCameraState();
}

class AttendanceCameraState extends State<AttendanceCamera> {
  final AttendanceService _attendanceService = AttendanceService();
  final LocationService _locationService = LocationService();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FaceLivenessService _liveness = FaceLivenessService();

  CameraController? _controller;
  Timer? _timer;

  bool _initializing = true;
  bool _processing = false;
  bool _verificationStarted = false;

  String _status =
      'Press Start, then follow the five steps. Turn your FACE left/right; do not tilt your head.';

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
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _status = 'Camera unavailable.';
      });

      Fluttertoast.showToast(
        msg: 'Camera error: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _startVerification() async {
    if (_verificationStarted ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        throw StateError('Please sign in again.');
      }

      final registered = await _faceService.hasRegisteredFace(uid);

      if (!registered) {
        throw StateError('Register your face first from Profile.');
      }

      final active = await _attendanceService.hasActiveSession(
        widget.classObj.classId,
      );

      if (!active) {
        throw StateError(
          'Your instructor has not opened attendance for this class.',
        );
      }

      setState(() {
        _verificationStarted = true;
        _status = _liveness.state.instruction;
      });

      _timer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => _scanFrame(uid),
      );

      unawaited(_scanFrame(uid));
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
    }
  }

  Future<void> _scanFrame(String uid) async {
    if (_processing ||
        !_verificationStarted ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    _processing = true;

    try {
      final photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();

      final capture = await _faceService.analyzeSingleFace(
        bytes,
        maxYaw: 40,
        maxPitch: 30,
        maxRoll: 25,
      );

      if (!_liveness.state.isComplete) {
        final state = _liveness.update(capture.face);

        if (mounted) {
          setState(() {
            _status = state.instruction;
          });
        }

        return;
      }

      _timer?.cancel();

      if (mounted) {
        setState(() {
          _status = 'Live face confirmed • verifying identity...';
        });
      }

      final verified = await _faceService.verifyStudent(
        studentId: uid,
        probeEmbedding: capture.embedding,
      );

      if (!verified) {
        throw StateError('The live face does not match the logged-in student.');
      }

      final similarity = await _faceService.studentSimilarity(
        studentId: uid,
        probeEmbedding: capture.embedding,
      );

      if (mounted) {
        setState(() {
          _status = 'Checking classroom location...';
        });
      }

      final position = await _getValidatedPosition();

      final queuedOffline = await _attendanceService
          .markRecognizedFaceAttendance(
            recognizedStudentId: uid,
            classObj: widget.classObj,
            latitude: position.$1,
            longitude: position.$2,
            confidence: similarity,
          );

      Fluttertoast.showToast(
        msg: queuedOffline
            ? 'Face verified. Attendance saved as Pending Sync and will upload when internet returns.'
            : 'Face verified. Attendance recorded.',
        backgroundColor: queuedOffline ? Colors.orange : Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      final message = e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('StateError: ', '');

      // Ordinary bad frames should not interrupt a liveness challenge.
      if (!_liveness.state.isComplete) {
        if (mounted) {
          setState(() {
            _status = '${_liveness.state.instruction} • one face, hold still';
          });
        }
      } else {
        _timer?.cancel();
        _liveness.reset();

        if (mounted) {
          setState(() {
            _verificationStarted = false;
            _status = 'Verification failed. Press Start to try again.';
          });
        }

        Fluttertoast.showToast(
          msg: message,
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } finally {
      _processing = false;
    }
  }

  Future<(double, double)> _getValidatedPosition() async {
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
      throw StateError('Unable to determine your current location.');
    }

    if (widget.classObj.latitude == null || widget.classObj.longitude == null) {
      throw StateError(
        'The administrator has not configured this classroom geofence.',
      );
    }

    final inside = await _locationService.isWithinGeofence(
      userLatitude: position.latitude,
      userLongitude: position.longitude,
      classroomLatitude: widget.classObj.latitude!,
      classroomLongitude: widget.classObj.longitude!,
      radiusMeters: widget.classObj.radiusMeters ?? 30,
    );

    if (!inside) {
      throw StateError(
        'You are outside the allowed classroom attendance area.',
      );
    }

    return (position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _verificationStarted ? _liveness.state.progress : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.classObj.classCode} Attendance'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _controller == null
          ? Center(
              child: Text(_status, style: const TextStyle(color: Colors.white)),
            )
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
                              color: _liveness.state.isComplete
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
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_verificationStarted) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: progress),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_verificationStarted)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: SafeArea(
                      top: false,
                      child: FilledButton.icon(
                        onPressed: _startVerification,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        icon: const Icon(Icons.verified_user_rounded),
                        label: const Text('Start Live Face Verification'),
                      ),
                    ),
                  ),
                if (_processing && _verificationStarted)
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
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
