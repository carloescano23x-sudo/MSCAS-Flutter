import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewSurface extends StatelessWidget {
  final CameraController controller;
  final BoxFit fit;

  const CameraPreviewSurface({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = controller.value.aspectRatio;
    final orientation = MediaQuery.orientationOf(context);

    final correctedRatio = orientation == Orientation.portrait
        ? 1 / aspectRatio
        : aspectRatio;

    if (fit == BoxFit.contain) {
      return Center(
        child: AspectRatio(
          aspectRatio: correctedRatio,
          child: CameraPreview(controller),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableRatio = constraints.maxWidth / constraints.maxHeight;

        var scale = correctedRatio / availableRatio;

        if (scale < 1) {
          scale = 1 / scale;
        }

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: correctedRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
