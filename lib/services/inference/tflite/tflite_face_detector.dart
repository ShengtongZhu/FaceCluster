import 'dart:math';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../face_detector.dart';

/// TFLite implementation of FaceDetector using SCRFD det_500m.
///
/// Preprocessing uses Float32List direct byte manipulation instead of
/// nested List.generate, avoiding creation of ~1.2M Dart objects per frame.
class TFLiteFaceDetector implements FaceDetector {
  static const int _inputSize = 640;
  static const List<int> _strides = [8, 16, 32];
  static const int _numAnchors = 2;

  Interpreter? _interpreter;

  @override
  String get backendName => 'TFLite';

  @override
  Future<void> loadModel() async {
    _interpreter =
        await Interpreter.fromAsset('assets/models/scrfd_500m.tflite');
  }

  @override
  DetectionResult detectSingle(
    Uint8List rgbBytes,
    int width,
    int height, {
    double scoreThreshold = 0.5,
  }) {
    if (_interpreter == null) throw StateError('Model not loaded');

    final sw = Stopwatch();

    // --- Preprocess ---
    sw.start();
    final scale = min(_inputSize / width, _inputSize / height);
    final newW = (width * scale).toInt();
    final newH = (height * scale).toInt();

    // Build Float32List input tensor directly: [1, 640, 640, 3]
    final inputSize = _inputSize * _inputSize * 3;
    final input = Float32List(inputSize);
    final padValue = -127.5 / 128.0;

    // Fill with pad value first
    for (int i = 0; i < inputSize; i++) {
      input[i] = padValue;
    }

    // Bilinear resize + normalize directly into Float32List
    for (int y = 0; y < newH; y++) {
      final srcYf = y * height / newH;
      final srcY0 = srcYf.floor().clamp(0, height - 1);
      final srcY1 = (srcY0 + 1).clamp(0, height - 1);
      final fy = srcYf - srcY0;

      for (int x = 0; x < newW; x++) {
        final srcXf = x * width / newW;
        final srcX0 = srcXf.floor().clamp(0, width - 1);
        final srcX1 = (srcX0 + 1).clamp(0, width - 1);
        final fx = srcXf - srcX0;

        final idx00 = (srcY0 * width + srcX0) * 3;
        final idx01 = (srcY0 * width + srcX1) * 3;
        final idx10 = (srcY1 * width + srcX0) * 3;
        final idx11 = (srcY1 * width + srcX1) * 3;

        final outIdx = (y * _inputSize + x) * 3;

        for (int c = 0; c < 3; c++) {
          final v00 = rgbBytes[idx00 + c].toDouble();
          final v01 = rgbBytes[idx01 + c].toDouble();
          final v10 = rgbBytes[idx10 + c].toDouble();
          final v11 = rgbBytes[idx11 + c].toDouble();

          final v = v00 * (1 - fx) * (1 - fy) +
              v01 * fx * (1 - fy) +
              v10 * (1 - fx) * fy +
              v11 * fx * fy;

          input[outIdx + c] = (v - 127.5) / 128.0;
        }
      }
    }

    final inputTensor = input.buffer.asFloat32List();
    final preprocessMs = sw.elapsedMicroseconds / 1000.0;

    // --- Inference ---
    sw.reset();
    final outputTensors = _interpreter!.getOutputTensors();
    final outputs = <int, List<List<double>>>{};
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      final rows = shape[0];
      final cols = shape[1];
      outputs[i] = List.generate(rows, (_) => List.filled(cols, 0.0));
    }

    // Reshape input to [1, 640, 640, 3] for tflite_flutter
    final inputReshaped = inputTensor.reshape([1, _inputSize, _inputSize, 3]);
    _interpreter!.runForMultipleInputs([inputReshaped], outputs);
    final inferenceMs = sw.elapsedMicroseconds / 1000.0;

    // --- Postprocess ---
    sw.reset();
    // Group outputs by shape
    final outputsByShape = <String, List<List<double>>>{};
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      final key = '${shape[0]}_${shape[1]}';
      outputsByShape[key] = outputs[i]!;
    }

    final allDetections = <RawDetection>[];

    for (final stride in _strides) {
      final fmSize = _inputSize ~/ stride;
      final nAnchors = fmSize * fmSize * _numAnchors;

      final scores = outputsByShape['${nAnchors}_1'];
      final bboxes = outputsByShape['${nAnchors}_4'];
      final kps = outputsByShape['${nAnchors}_10'];

      if (scores == null || bboxes == null || kps == null) continue;

      int anchorIdx = 0;
      for (int row = 0; row < fmSize; row++) {
        for (int col = 0; col < fmSize; col++) {
          for (int a = 0; a < _numAnchors; a++) {
            final s = scores[anchorIdx][0];
            if (s > scoreThreshold) {
              final cx = col * stride.toDouble();
              final cy = row * stride.toDouble();

              final x1 = (cx - bboxes[anchorIdx][0] * stride) / scale;
              final y1 = (cy - bboxes[anchorIdx][1] * stride) / scale;
              final x2 = (cx + bboxes[anchorIdx][2] * stride) / scale;
              final y2 = (cy + bboxes[anchorIdx][3] * stride) / scale;

              final keypoints = <List<double>>[];
              for (int k = 0; k < 5; k++) {
                final kx = (cx + kps[anchorIdx][k * 2] * stride) / scale;
                final ky = (cy + kps[anchorIdx][k * 2 + 1] * stride) / scale;
                keypoints.add([kx, ky]);
              }

              allDetections.add(RawDetection(
                x1: x1.clamp(0, width.toDouble()),
                y1: y1.clamp(0, height.toDouble()),
                x2: x2.clamp(0, width.toDouble()),
                y2: y2.clamp(0, height.toDouble()),
                score: s,
                keypoints: keypoints,
              ));
            }
            anchorIdx++;
          }
        }
      }
    }

    final result = nms(allDetections, 0.4);
    final postprocessMs = sw.elapsedMicroseconds / 1000.0;

    return DetectionResult(
      detections: result,
      timing: DetectionTiming(
        preprocessMs: preprocessMs,
        inferenceMs: inferenceMs,
        postprocessMs: postprocessMs,
      ),
    );
  }

  @override
  List<RawDetection> nms(List<RawDetection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];

    detections.sort((a, b) => b.score.compareTo(a.score));

    final keep = <RawDetection>[];
    final suppressed = List.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      keep.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i], detections[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return keep;
  }

  double _iou(RawDetection a, RawDetection b) {
    final x1 = max(a.x1, b.x1);
    final y1 = max(a.y1, b.y1);
    final x2 = min(a.x2, b.x2);
    final y2 = min(a.y2, b.y2);

    final inter = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;

    return inter / (areaA + areaB - inter);
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}
