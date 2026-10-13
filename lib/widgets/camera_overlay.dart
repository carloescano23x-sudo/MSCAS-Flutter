import 'package:flutter/material.dart';

class CameraOverlay extends StatelessWidget {
  const CameraOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          // Corner markers
          Positioned(
            top: -2,
            left: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white, width: 4),
                  left: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white, width: 4),
                  right: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            left: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: 4),
                  left: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: 4),
                  right: BorderSide(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
          // Center text
          const Center(
            child: Text(
              '📸',
              style: TextStyle(
                fontSize: 40,
                shadows: [Shadow(color: Colors.black38, blurRadius: 10)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
