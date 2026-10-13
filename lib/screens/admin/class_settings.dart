import 'package:flutter/material.dart';

class ClassSettingsScreen extends StatelessWidget {
  const ClassSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Class and classroom settings are managed from the current Admin Dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
