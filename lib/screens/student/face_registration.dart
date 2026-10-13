import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../services/face_recognition_service.dart';
import '../../widgets/camera_preview_surface.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final FaceRecognitionService _faceService = FaceRecognitionService();

  CameraController? _controller;
  Timer? _timer;

  final List<List<double>> _samples = [];

  bool _initializing = true;
  bool _processing = false;

  String _status = 'Preparing camera...';

  // First and last are neutral. Middle samples intentionally cover both
  // small head directions so templates are not five copies of the same pose.
  int? _firstSideSign;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      var selected = cameras.first;

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
        _status = _instructionForStage();
      });

      await Future<void>.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      _timer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _tryCapture(),
      );

      unawaited(_tryCapture());
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _status = 'Camera could not be started.';
      });

      Fluttertoast.showToast(
        msg: 'Camera error: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  String _instructionForStage() {
    switch (_samples.length) {
      case 0:
        return 'Look straight at the camera';
      case 1:
        return 'Turn your head slightly to either side';
      case 2:
        return 'Look straight at the camera again';
      case 3:
        return 'Turn slightly to the opposite side';
      case 4:
        return 'Return to the center and hold still';
      default:
        return 'Finishing registration...';
    }
  }

  bool _poseMatches(FaceCaptureAnalysis capture) {
    final yaw = capture.face.headEulerAngleY;

    switch (_samples.length) {
      case 0:
      case 2:
      case 4:
        return yaw.abs() <= 9;

      case 1:
        if (yaw.abs() < 11 || yaw.abs() > 25) {
          return false;
        }

        _firstSideSign = yaw >= 0 ? 1 : -1;
        return true;

      case 3:
        final firstSign = _firstSideSign;
        if (firstSign == null) return false;

        if (yaw.abs() < 11 || yaw.abs() > 25) {
          return false;
        }

        final currentSign = yaw >= 0 ? 1 : -1;
        return currentSign != firstSign;

      default:
        return false;
    }
  }

  Future<void> _tryCapture() async {
    if (_processing ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _samples.length >= FaceRecognitionService.requiredRegistrationSamples) {
      return;
    }

    _processing = true;

    try {
      final photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();

      final capture = await _faceService.analyzeSingleFace(bytes, maxYaw: 28);

      if (!_poseMatches(capture)) {
        if (mounted) {
          setState(() {
            _status =
                '${_instructionForStage()} • hold the requested position briefly';
          });
        }
        return;
      }

      _samples.add(capture.embedding);

      if (_samples.length >=
          FaceRecognitionService.requiredRegistrationSamples) {
        _timer?.cancel();

        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

        if (uid.isEmpty) {
          throw StateError('Please sign in again.');
        }

        await _faceService.saveRegistrationSamples(
          studentId: uid,
          samples: _samples,
        );

        if (!mounted) return;

        Fluttertoast.showToast(
          msg: 'Face registration completed.',
          backgroundColor: Colors.green,
        );

        Navigator.pop(context, true);
        return;
      }

      if (mounted) {
        setState(() {
          _status = _instructionForStage();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status =
              '${_instructionForStage()} • one face, good lighting, hold still';
        });
      }
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _samples.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register Face'),
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
                              color: _processing
                                  ? Colors.lightBlueAccent
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
                        color: Colors.black.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Automatic Face Registration',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '$count / ${FaceRecognitionService.requiredRegistrationSamples} good captures',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'No capture button needed.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 28,
                  child: SafeArea(
                    top: false,
                    child: LinearProgressIndicator(
                      value:
                          count /
                          FaceRecognitionService.requiredRegistrationSamples,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
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
