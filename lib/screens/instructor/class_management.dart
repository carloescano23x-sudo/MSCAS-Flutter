import 'package:flutter/material.dart';

class ClassManagementScreen extends StatelessWidget {
  const ClassManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Instructor class management is handled by the current Instructor Dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
