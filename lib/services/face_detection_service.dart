import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class DetectedFace {
  final double bboxX;
  final double bboxY;
  final double bboxW;
  final double bboxH;
  final img.Image alignedFace;

  DetectedFace({
    required this.bboxX,
    required this.bboxY,
    required this.bboxW,
    required this.bboxH,
    required this.alignedFace,
  });
}

class FaceDetectionService {
  late final FaceDetector _detector;

  FaceDetectionService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<List<DetectedFace>> detectFaces(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) return [];

    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    final fullImage = img.decodeImage(imageBytes);
    if (fullImage == null) return [];

    final imageWidth = fullImage.width.toDouble();
    final imageHeight = fullImage.height.toDouble();

    final results = <DetectedFace>[];

    for (final face in faces) {
      final bbox = face.boundingBox;

      // Normalize bounding box
      final normX = bbox.left / imageWidth;
      final normY = bbox.top / imageHeight;
      final normW = bbox.width / imageWidth;
      final normH = bbox.height / imageHeight;

      // Crop and align face
      final aligned = _cropAndAlign(fullImage, face);

      results.add(DetectedFace(
        bboxX: normX,
        bboxY: normY,
        bboxW: normW,
        bboxH: normH,
        alignedFace: aligned,
      ));
    }

    return results;
  }

  img.Image _cropAndAlign(img.Image image, Face face) {
    final bbox = face.boundingBox;

    // Expand bounding box slightly for better face coverage
    final padding = bbox.width * 0.2;
    final x = max(0, (bbox.left - padding).toInt());
    final y = max(0, (bbox.top - padding).toInt());
    final w = min(image.width - x, (bbox.width + padding * 2).toInt());
    final h = min(image.height - y, (bbox.height + padding * 2).toInt());

    // Crop face region
    final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

    // Check for eye landmarks for alignment
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    img.Image aligned;
    if (leftEye != null && rightEye != null) {
      // Calculate rotation angle from eye positions
      final dx = rightEye.position.x - leftEye.position.x;
      final dy = rightEye.position.y - leftEye.position.y;
      final angle = atan2(dy.toDouble(), dx.toDouble());

      if (angle.abs() > 0.01) {
        // Rotate to align eyes horizontally
        aligned = img.copyRotate(cropped, angle: -angle * 180 / pi);
      } else {
        aligned = cropped;
      }
    } else {
      aligned = cropped;
    }

    // Resize to 112x112
    return img.copyResize(aligned, width: 112, height: 112);
  }

  void dispose() {
    _detector.close();
  }
}
