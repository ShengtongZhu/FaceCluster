import 'dart:typed_data';

/// Raw detection result from a backend detector.
class RawDetection {
  final double x1, y1, x2, y2;
  final double score;
  final List<List<double>> keypoints; // 5 points: [x, y] each

  RawDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.keypoints,
  });

  double get width => x2 - x1;
  double get height => y2 - y1;
}

/// Timing breakdown for a single detection call.
class DetectionTiming {
  final double preprocessMs;
  final double inferenceMs;
  final double postprocessMs;

  DetectionTiming({
    required this.preprocessMs,
    required this.inferenceMs,
    required this.postprocessMs,
  });

  double get totalMs => preprocessMs + inferenceMs + postprocessMs;
}

/// Result of detectSingle, including detections and timing.
class DetectionResult {
  final List<RawDetection> detections;
  final DetectionTiming timing;

  DetectionResult({required this.detections, required this.timing});
}

/// Abstract interface for face detection backends.
///
/// Implementations receive raw RGB bytes and handle all preprocessing
/// (resize, normalize, etc.) internally for maximum performance.
abstract class FaceDetector {
  /// Human-readable backend name (e.g., "TFLite", "NCNN").
  String get backendName;

  /// Load the detection model. Must be called before detectSingle.
  Future<void> loadModel();

  /// Detect faces in a single image.
  ///
  /// [rgbBytes]: Raw RGB pixel data, 3 bytes per pixel, row-major order.
  /// [width], [height]: Image dimensions.
  /// [scoreThreshold]: Minimum detection confidence.
  ///
  /// Returns detected faces with coordinates in original image space.
  DetectionResult detectSingle(
    Uint8List rgbBytes,
    int width,
    int height, {
    double scoreThreshold = 0.5,
  });

  /// NMS across detections from multiple tiles/scales.
  List<RawDetection> nms(List<RawDetection> detections, double iouThreshold);

  /// Release model resources.
  void dispose();
}
