import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../face_embedder.dart';

/// TFLite implementation of FaceEmbedder using MobileFaceNet.
///
/// Preprocessing uses Float32List direct byte manipulation instead of
/// nested List.generate, avoiding creation of ~37K Dart objects per face.
class TFLiteFaceEmbedder implements FaceEmbedder {
  static const int _embeddingDim = 512;
  Interpreter? _interpreter;

  @override
  String get backendName => 'TFLite';

  @override
  int get embeddingDim => _embeddingDim;

  @override
  Future<void> loadModel() async {
    _interpreter =
        await Interpreter.fromAsset('assets/models/MobileFaceNet.tflite');

    final outputTensors = _interpreter!.getOutputTensors();
    if (outputTensors.isEmpty || outputTensors[0].shape.last != _embeddingDim) {
      throw StateError(
        'Expected model output dimension $_embeddingDim, '
        'got ${outputTensors.isEmpty ? "none" : outputTensors[0].shape.last}',
      );
    }
  }

  @override
  EmbeddingResult getEmbedding(Uint8List bgrBytes, int width, int height) {
    if (_interpreter == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final sw = Stopwatch();

    // --- Preprocess ---
    sw.start();
    final pixelCount = width * height;
    final input = Float32List(pixelCount * 3);

    // BGR bytes → Float32List, normalized to [-1, 1]
    // BGR channel order preserved as model expects it
    for (int i = 0; i < pixelCount; i++) {
      final srcIdx = i * 3;
      final dstIdx = i * 3;
      input[dstIdx] = (bgrBytes[srcIdx].toDouble() - 127.5) / 128.0;
      input[dstIdx + 1] = (bgrBytes[srcIdx + 1].toDouble() - 127.5) / 128.0;
      input[dstIdx + 2] = (bgrBytes[srcIdx + 2].toDouble() - 127.5) / 128.0;
    }

    final inputReshaped = input.reshape([1, height, width, 3]);
    final preprocessMs = sw.elapsedMicroseconds / 1000.0;

    // --- Inference ---
    sw.reset();
    final output = List.generate(1, (_) => List.filled(_embeddingDim, 0.0));
    _interpreter!.run(inputReshaped, output);
    final inferenceMs = sw.elapsedMicroseconds / 1000.0;

    // --- Postprocess (L2 normalization) ---
    sw.reset();
    final embedding = Float32List.fromList(output[0]);
    _normalize(embedding);
    final postprocessMs = sw.elapsedMicroseconds / 1000.0;

    return EmbeddingResult(
      embedding: embedding,
      timing: EmbeddingTiming(
        preprocessMs: preprocessMs,
        inferenceMs: inferenceMs,
        postprocessMs: postprocessMs,
      ),
    );
  }

  void _normalize(Float32List vector) {
    double norm = 0;
    for (final v in vector) {
      norm += v * v;
    }
    final invNorm = norm > 0 ? 1.0 / math.sqrt(norm) : 1.0;
    for (int i = 0; i < vector.length; i++) {
      vector[i] *= invNorm;
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}
