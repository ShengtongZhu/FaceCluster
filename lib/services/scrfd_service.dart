import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class SCRFDFace {
  final double x1, y1, x2, y2;
  final double score;
  final List<List<double>> keypoints; // 5 points: [x, y] each

  SCRFDFace({
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

class SCRFDService {
  static const int _inputSize = 640;
  static const List<int> _strides = [8, 16, 32];
  static const int _numAnchors = 2;

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/scrfd_500m.tflite');
    print('[SCRFD] Model loaded, input: ${_interpreter!.getInputTensors().map((t) => t.shape)}');
    print('[SCRFD] Outputs: ${_interpreter!.getOutputTensors().map((t) => '${t.shape}')}');
  }

  List<SCRFDFace> detect(img.Image image, {double scoreThreshold = 0.5, double nmsThreshold = 0.4}) {
    if (_interpreter == null) throw StateError('Model not loaded');

    final origW = image.width;
    final origH = image.height;

    // Prepare input: resize + letterbox to 640x640
    final scale = min(_inputSize / origW, _inputSize / origH);
    final newW = (origW * scale).toInt();
    final newH = (origH * scale).toInt();

    final resized = img.copyResize(image, width: newW, height: newH);

    // Build input tensor [1, 640, 640, 3] RGB normalized to [-1, 1]
    // SCRFD requires: (pixel - 127.5) / 128.0, RGB channel order
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            if (x < newW && y < newH) {
              final pixel = resized.getPixel(x, y);
              // RGB order, normalized
              return [
                (pixel.r.toDouble() - 127.5) / 128.0,
                (pixel.g.toDouble() - 127.5) / 128.0,
                (pixel.b.toDouble() - 127.5) / 128.0,
              ];
            }
            return [-127.5 / 128.0, -127.5 / 128.0, -127.5 / 128.0]; // normalized padding
          },
        ),
      ),
    );

    // Get output tensors info
    final outputTensors = _interpreter!.getOutputTensors();
    final outputs = <int, List<List<double>>>{};
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      final rows = shape[0];
      final cols = shape[1];
      outputs[i] = List.generate(rows, (_) => List.filled(cols, 0.0));
    }

    _interpreter!.runForMultipleInputs([input], outputs);

    // Group outputs by shape: for each stride level, find scores (cols=1), bbox (cols=4), kps (cols=10)
    final outputsByShape = <String, List<List<double>>>{};
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      final key = '${shape[0]}_${shape[1]}';
      outputsByShape[key] = outputs[i]!;
    }

    final allFaces = <SCRFDFace>[];

    for (final stride in _strides) {
      final fmSize = _inputSize ~/ stride;
      final nAnchors = fmSize * fmSize * _numAnchors;

      final scores = outputsByShape['${nAnchors}_1'];
      final bboxes = outputsByShape['${nAnchors}_4'];
      final kps = outputsByShape['${nAnchors}_10'];

      if (scores == null || bboxes == null || kps == null) continue;

      // Generate anchor centers
      int anchorIdx = 0;
      for (int row = 0; row < fmSize; row++) {
        for (int col = 0; col < fmSize; col++) {
          for (int a = 0; a < _numAnchors; a++) {
            final s = scores[anchorIdx][0];
            if (s > scoreThreshold) {
              final cx = col * stride.toDouble();
              final cy = row * stride.toDouble();

              // Decode bbox
              final x1 = (cx - bboxes[anchorIdx][0] * stride) / scale;
              final y1 = (cy - bboxes[anchorIdx][1] * stride) / scale;
              final x2 = (cx + bboxes[anchorIdx][2] * stride) / scale;
              final y2 = (cy + bboxes[anchorIdx][3] * stride) / scale;

              // Decode keypoints
              final keypoints = <List<double>>[];
              for (int k = 0; k < 5; k++) {
                final kx = (cx + kps[anchorIdx][k * 2] * stride) / scale;
                final ky = (cy + kps[anchorIdx][k * 2 + 1] * stride) / scale;
                keypoints.add([kx, ky]);
              }

              allFaces.add(SCRFDFace(
                x1: x1.clamp(0, origW.toDouble()),
                y1: y1.clamp(0, origH.toDouble()),
                x2: x2.clamp(0, origW.toDouble()),
                y2: y2.clamp(0, origH.toDouble()),
                score: s,
                keypoints: keypoints,
              ));
            }
            anchorIdx++;
          }
        }
      }
    }

    // NMS
    return _nms(allFaces, nmsThreshold);
  }

  /// Public NMS for cross-tile deduplication in multi-scale detection
  List<SCRFDFace> nms(List<SCRFDFace> faces, double threshold) {
    return _nms(faces, threshold);
  }

  List<SCRFDFace> _nms(List<SCRFDFace> faces, double threshold) {
    if (faces.isEmpty) return [];

    faces.sort((a, b) => b.score.compareTo(a.score));

    final keep = <SCRFDFace>[];
    final suppressed = List.filled(faces.length, false);

    for (int i = 0; i < faces.length; i++) {
      if (suppressed[i]) continue;
      keep.add(faces[i]);

      for (int j = i + 1; j < faces.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(faces[i], faces[j]) > threshold) {
          suppressed[j] = true;
        }
      }
    }

    return keep;
  }

  double _iou(SCRFDFace a, SCRFDFace b) {
    final x1 = max(a.x1, b.x1);
    final y1 = max(a.y1, b.y1);
    final x2 = min(a.x2, b.x2);
    final y2 = min(a.y2, b.y2);

    final inter = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;

    return inter / (areaA + areaB - inter);
  }

  void dispose() {
    _interpreter?.close();
  }
}
