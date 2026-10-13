import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Attendance report preview and printing are available from the current Instructor Web Portal.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
