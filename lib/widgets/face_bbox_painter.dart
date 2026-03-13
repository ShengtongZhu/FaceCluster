import 'dart:io';

import 'package:flutter/material.dart';

import '../models/database.dart';

class FaceBboxPainter extends CustomPainter {
  final List<Face> faces;

  FaceBboxPainter({required this.faces});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final face in faces) {
      final rect = Rect.fromLTWH(
        face.bboxX * size.width,
        face.bboxY * size.height,
        face.bboxW * size.width,
        face.bboxH * size.height,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FaceBboxPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}

class PhotoWithBboxes extends StatelessWidget {
  final String photoPath;
  final List<Face> faces;

  const PhotoWithBboxes({
    super.key,
    required this.photoPath,
    required this.faces,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(photoPath),
          fit: BoxFit.contain,
        ),
        CustomPaint(
          painter: FaceBboxPainter(faces: faces),
        ),
      ],
    );
  }
}
