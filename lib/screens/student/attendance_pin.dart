import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/location_service.dart';

class AttendancePin extends StatefulWidget {
  final Class classObj;

  const AttendancePin({super.key, required this.classObj});

  @override
  State<AttendancePin> createState() => AttendancePinState();
}

class AttendancePinState extends State<AttendancePin> {
  final AttendanceService _attendanceService = AttendanceService();
  final LocationService _locationService = LocationService();

  String _pin = '';
  bool _isLoading = false;

  Future<void> _submitPin() async {
    if (_pin.length != 6 || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final studentId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw StateError('Please sign in again.');
      }

      final serviceEnabled = await _locationService.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw StateError(
          'Turn on GPS/Location services before marking attendance.',
        );
      }

      final hasPermission = await _locationService.hasPermission();
      if (!hasPermission) {
        throw StateError('Location permission is required for attendance.');
      }

      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw StateError('Unable to determine your current location.');
      }

      if (widget.classObj.latitude == null ||
          widget.classObj.longitude == null) {
        throw StateError(
          'This classroom has no geofence configured yet. Ask the administrator to add the classroom coordinates.',
        );
      }

      final isWithin = await _locationService.isWithinGeofence(
        userLatitude: position.latitude,
        userLongitude: position.longitude,
        classroomLatitude: widget.classObj.latitude!,
        classroomLongitude: widget.classObj.longitude!,
        radiusMeters: widget.classObj.radiusMeters ?? 30,
      );

      if (!isWithin) {
        throw StateError(
          'You are outside the allowed classroom attendance area.',
        );
      }

      await _attendanceService.markAttendancePin(
        studentId: studentId,
        classObj: widget.classObj,
        pin: _pin,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      Fluttertoast.showToast(
        msg: 'Attendance marked successfully.',
        backgroundColor: Colors.green,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
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

      if (mounted) {
        setState(() => _pin = '');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _press(String value) {
    if (_isLoading) return;

    if (value == 'delete') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
        });
      }
      return;
    }

    if (_pin.length < 6) {
      setState(() => _pin += value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN Fallback')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Icon(
                    Icons.pin_rounded,
                    size: 72,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.classObj.classCode,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.classObj.className,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Enter the 6-digit PIN shown by your instructor.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final filled = index < _pin.length;

                      return Container(
                        width: 42,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: filled
                                ? Colors.orange.shade700
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: filled
                            ? const Icon(Icons.circle, size: 13)
                            : null,
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      for (final value in const [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                      ])
                        _key(value),
                      const SizedBox.shrink(),
                      _key('0'),
                      _key('delete'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _pin.length == 6 && !_isLoading
                          ? _submitPin
                          : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _isLoading ? 'Checking...' : 'Submit Attendance',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _key(String value) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _press(value),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: value == 'delete'
              ? const Icon(Icons.backspace_outlined)
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
