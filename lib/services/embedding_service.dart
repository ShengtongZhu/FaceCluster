import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EmbeddingService {
  static const int _embeddingDim = 512;
  Interpreter? _interpreter;

  int get embeddingDim => _embeddingDim;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/MobileFaceNet.tflite');

    // Verify output dimension is 512
    final outputTensors = _interpreter!.getOutputTensors();
    if (outputTensors.isEmpty || outputTensors[0].shape.last != _embeddingDim) {
      throw StateError(
        'Expected model output dimension $_embeddingDim, '
        'got ${outputTensors.isEmpty ? "none" : outputTensors[0].shape.last}',
      );
    }
  }

  Float32List getEmbedding(img.Image alignedFace) {
    if (_interpreter == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    // Prepare input: [1, 112, 112, 3] float32
    final input = _imageToFloat32List(alignedFace);

    // Prepare output: [1, embeddingDim] float32
    final output = List.generate(1, (_) => List.filled(_embeddingDim, 0.0));

    _interpreter!.run(input, output);

    // Normalize the embedding vector
    final embedding = Float32List.fromList(output[0]);
    _normalize(embedding);

    return embedding;
  }

  List<List<List<List<double>>>> _imageToFloat32List(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final pixel = image.getPixel(x, y);
            // BGR channel order for InsightFace, normalized to [-1, 1]
            return [
              (pixel.b.toDouble() - 127.5) / 128.0,
              (pixel.g.toDouble() - 127.5) / 128.0,
              (pixel.r.toDouble() - 127.5) / 128.0,
            ];
          },
        ),
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

  void dispose() {
    _interpreter?.close();
  }
}
