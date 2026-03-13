import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../face_detector.dart';
import 'ncnn_bindings.dart';

/// NCNN implementation of FaceDetector using SCRFD det_500m.
///
/// Preprocessing uses NCNN native Mat::from_pixels_resize + substract_mean_normalize
/// which leverages ARM NEON for maximum performance.
class NcnnFaceDetector implements FaceDetector {
  static const int _inputSize = 640;
  static const List<int> _strides = [8, 16, 32];
  static const int _numAnchors = 2;
  static const int _numOutputs = 9;

  // NCNN blob names (pnnx-renamed)
  static const String _inputName = 'in0';
  static const List<String> _outputNames = [
    'out0', 'out1', 'out2', // scores: 12800x1, 3200x1, 800x1
    'out3', 'out4', 'out5', // bbox: 12800x4, 3200x4, 800x4
    'out6', 'out7', 'out8', // kps: 12800x10, 3200x10, 800x10
  ];

  // SCRFD normalization: (pixel - 127.5) / 128.0
  // In NCNN: mean = [127.5, 127.5, 127.5], norm = [1/128, 1/128, 1/128]
  static final Float32List _meanVals = Float32List.fromList([127.5, 127.5, 127.5]);
  static final Float32List _normVals = Float32List.fromList([1.0 / 128.0, 1.0 / 128.0, 1.0 / 128.0]);

  Pointer<Void>? _net;
  final NcnnBindings _bindings = NcnnBindings.instance;

  @override
  String get backendName => 'NCNN';

  @override
  Future<void> loadModel() async {
    if (!_bindings.isAvailable) {
      throw StateError('NCNN native library not available');
    }

    _net = _bindings.createNet(4); // 4 threads

    // Load model from Flutter assets
    print('[NCNN] Loading SCRFD param...');
    final paramData = await rootBundle.load('assets/models/scrfd_500m.param');
    print('[NCNN] SCRFD param loaded: ${paramData.lengthInBytes} bytes');
    final modelData = await rootBundle.load('assets/models/scrfd_500m.bin');
    print('[NCNN] SCRFD model loaded: ${modelData.lengthInBytes} bytes');

    final paramPtr = calloc<Uint8>(paramData.lengthInBytes);
    final modelPtr = calloc<Uint8>(modelData.lengthInBytes);

    final paramBytes = paramData.buffer.asUint8List();
    paramPtr.asTypedList(paramData.lengthInBytes).setAll(0, paramBytes);
    modelPtr.asTypedList(modelData.lengthInBytes)
        .setAll(0, modelData.buffer.asUint8List());

    // Debug: verify first bytes of param (should be "7767517\n")
    print('[NCNN] Param first bytes: ${paramBytes.take(20).toList()}');

    final ret = _bindings.loadModel(
        _net!, paramPtr, paramData.lengthInBytes, modelPtr, modelData.lengthInBytes);

    calloc.free(paramPtr);
    calloc.free(modelPtr);

    print('[NCNN] Load model returned: $ret');
    if (ret != 0) {
      throw StateError('Failed to load NCNN SCRFD model (ret=$ret)');
    }
  }

  @override
  DetectionResult detectSingle(
    Uint8List rgbBytes,
    int width,
    int height, {
    double scoreThreshold = 0.5,
  }) {
    if (_net == null) throw StateError('Model not loaded');

    final sw = Stopwatch();

    // --- Preprocess + Inference (done natively by NCNN) ---
    sw.start();

    // Allocate native buffers
    final pixelsPtr = calloc<Uint8>(rgbBytes.length);
    pixelsPtr.asTypedList(rgbBytes.length).setAll(0, rgbBytes);

    final meanPtr = calloc<Float>(3);
    final normPtr = calloc<Float>(3);
    meanPtr.asTypedList(3).setAll(0, _meanVals);
    normPtr.asTypedList(3).setAll(0, _normVals);

    // Input name
    final inputNamePtr = _inputName.toNativeUtf8();

    // Output names
    final outputNamesPtr = calloc<Pointer<Utf8>>(_numOutputs);
    final outputNamePtrs = <Pointer<Utf8>>[];
    for (int i = 0; i < _numOutputs; i++) {
      final ptr = _outputNames[i].toNativeUtf8();
      outputNamePtrs.add(ptr);
      outputNamesPtr[i] = ptr;
    }

    // Output buffer - max possible output size
    // scores: 12800+3200+800 = 16800, bbox: 16800*4 = 67200, kps: 16800*10 = 168000
    // Total: ~252000 floats
    const maxBuffer = 300000;
    final outBuffer = calloc<Float>(maxBuffer);
    final outSizes = calloc<Int32>(_numOutputs);

    // Timing output: [0] = preprocess ms, [1] = inference ms (measured in native C)
    final outTiming = calloc<Float>(2);

    final dartAllocMs = sw.elapsedMicroseconds / 1000.0;

    // --- Native call (preprocess + inference, timing split inside C) ---
    sw.reset();
    final totalFloats = _bindings.detect(
        _net!, pixelsPtr, width, height, _inputSize, _inputSize,
        meanPtr, normPtr, inputNamePtr.cast(),
        outputNamesPtr.cast(), _numOutputs,
        outBuffer, outSizes, maxBuffer, outTiming);

    // Native timing from C bridge (resize+normalize vs extract)
    final nativePreprocessMs = outTiming[0];
    final nativeInferenceMs = outTiming[1];
    // Total preprocess = Dart alloc + native resize/normalize
    final preprocessMs = dartAllocMs + nativePreprocessMs;
    final inferenceMs = nativeInferenceMs;

    // --- Postprocess ---
    sw.reset();

    List<RawDetection> detections = [];

    if (totalFloats > 0) {
      // NCNN from_pixels_resize stretches to 640x640 (not letterbox),
      // so x and y have different scale factors.
      final scaleX = _inputSize / width;
      final scaleY = _inputSize / height;
      int offset = 0;

      // Collect outputs into lists
      final outputs = <List<double>>[];
      for (int i = 0; i < _numOutputs; i++) {
        final size = outSizes[i];
        final data = <double>[];
        for (int j = 0; j < size; j++) {
          data.add(outBuffer[offset + j]);
        }
        outputs.add(data);
        offset += size;
      }

      // Decode detections per stride
      for (int s = 0; s < 3; s++) {
        final stride = _strides[s];
        final fmSize = _inputSize ~/ stride;
        final nAnchors = fmSize * fmSize * _numAnchors;

        final scores = outputs[s]; // s=0,1,2 → scores
        final bboxes = outputs[s + 3]; // s+3=3,4,5 → bbox
        final kps = outputs[s + 6]; // s+6=6,7,8 → kps

        if (scores.length != nAnchors) continue;

        int anchorIdx = 0;
        for (int row = 0; row < fmSize; row++) {
          for (int col = 0; col < fmSize; col++) {
            for (int a = 0; a < _numAnchors; a++) {
              final sc = scores[anchorIdx];
              if (sc > scoreThreshold) {
                final cx = col * stride.toDouble();
                final cy = row * stride.toDouble();

                final bi = anchorIdx * 4;
                final x1 = (cx - bboxes[bi] * stride) / scaleX;
                final y1 = (cy - bboxes[bi + 1] * stride) / scaleY;
                final x2 = (cx + bboxes[bi + 2] * stride) / scaleX;
                final y2 = (cy + bboxes[bi + 3] * stride) / scaleY;

                final keypoints = <List<double>>[];
                final ki = anchorIdx * 10;
                for (int k = 0; k < 5; k++) {
                  final kx = (cx + kps[ki + k * 2] * stride) / scaleX;
                  final ky = (cy + kps[ki + k * 2 + 1] * stride) / scaleY;
                  keypoints.add([kx, ky]);
                }

                detections.add(RawDetection(
                  x1: x1.clamp(0, width.toDouble()),
                  y1: y1.clamp(0, height.toDouble()),
                  x2: x2.clamp(0, width.toDouble()),
                  y2: y2.clamp(0, height.toDouble()),
                  score: sc,
                  keypoints: keypoints,
                ));
              }
              anchorIdx++;
            }
          }
        }
      }

      detections = nms(detections, 0.4);
    }

    final postprocessMs = sw.elapsedMicroseconds / 1000.0;

    // Free native memory
    calloc.free(pixelsPtr);
    calloc.free(meanPtr);
    calloc.free(normPtr);
    calloc.free(inputNamePtr);
    for (final ptr in outputNamePtrs) {
      calloc.free(ptr);
    }
    calloc.free(outputNamesPtr);
    calloc.free(outBuffer);
    calloc.free(outSizes);
    calloc.free(outTiming);

    return DetectionResult(
      detections: detections,
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
    if (_net != null) {
      _bindings.destroyNet(_net!);
      _net = null;
    }
  }
}
