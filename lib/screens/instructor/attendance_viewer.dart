import 'package:flutter/material.dart';

class AttendanceViewerScreen extends StatelessWidget {
  const AttendanceViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Attendance records are available from the current Instructor Dashboard and Reports.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
