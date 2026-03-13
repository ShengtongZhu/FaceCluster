import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../face_embedder.dart';
import 'ncnn_bindings.dart';

/// NCNN implementation of FaceEmbedder using MobileFaceNet w600k_mbf.
///
/// Preprocessing uses NCNN native Mat::from_pixels + substract_mean_normalize.
class NcnnFaceEmbedder implements FaceEmbedder {
  static const int _embeddingDim = 512;
  static const String _inputName = 'in0';
  static const String _outputName = 'out0';

  // MobileFaceNet normalization: (pixel - 127.5) / 128.0, BGR order
  static final Float32List _meanVals = Float32List.fromList([127.5, 127.5, 127.5]);
  static final Float32List _normVals = Float32List.fromList([1.0 / 128.0, 1.0 / 128.0, 1.0 / 128.0]);

  Pointer<Void>? _net;
  final NcnnBindings _bindings = NcnnBindings.instance;

  @override
  String get backendName => 'NCNN';

  @override
  int get embeddingDim => _embeddingDim;

  @override
  Future<void> loadModel() async {
    if (!_bindings.isAvailable) {
      throw StateError('NCNN native library not available');
    }

    _net = _bindings.createNet(4);

    final paramData = await rootBundle.load('assets/models/mobilefacenet.param');
    final modelData = await rootBundle.load('assets/models/mobilefacenet.bin');

    final paramPtr = calloc<Uint8>(paramData.lengthInBytes);
    final modelPtr = calloc<Uint8>(modelData.lengthInBytes);

    paramPtr.asTypedList(paramData.lengthInBytes)
        .setAll(0, paramData.buffer.asUint8List());
    modelPtr.asTypedList(modelData.lengthInBytes)
        .setAll(0, modelData.buffer.asUint8List());

    final ret = _bindings.loadModel(
        _net!, paramPtr, paramData.lengthInBytes, modelPtr, modelData.lengthInBytes);

    calloc.free(paramPtr);
    calloc.free(modelPtr);

    if (ret != 0) {
      throw StateError('Failed to load NCNN MobileFaceNet model (ret=$ret)');
    }
  }

  @override
  EmbeddingResult getEmbedding(Uint8List bgrBytes, int width, int height) {
    if (_net == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final sw = Stopwatch();

    // --- Preprocess (copy to native) ---
    sw.start();
    final pixelsPtr = calloc<Uint8>(bgrBytes.length);
    pixelsPtr.asTypedList(bgrBytes.length).setAll(0, bgrBytes);

    final meanPtr = calloc<Float>(3);
    final normPtr = calloc<Float>(3);
    meanPtr.asTypedList(3).setAll(0, _meanVals);
    normPtr.asTypedList(3).setAll(0, _normVals);

    final inputNamePtr = _inputName.toNativeUtf8();
    final outputNamePtr = _outputName.toNativeUtf8();
    final outPtr = calloc<Float>(_embeddingDim);

    final preprocessMs = sw.elapsedMicroseconds / 1000.0;

    // --- Inference ---
    sw.reset();
    final ret = _bindings.embed(
        _net!, pixelsPtr, width, height,
        meanPtr, normPtr,
        inputNamePtr.cast(), outputNamePtr.cast(),
        outPtr, _embeddingDim);
    final inferenceMs = sw.elapsedMicroseconds / 1000.0;

    // --- Postprocess (L2 normalization) ---
    sw.reset();
    final embedding = Float32List(_embeddingDim);
    if (ret == 0) {
      for (int i = 0; i < _embeddingDim; i++) {
        embedding[i] = outPtr[i];
      }
      _normalize(embedding);
    }
    final postprocessMs = sw.elapsedMicroseconds / 1000.0;

    // Free native memory
    calloc.free(pixelsPtr);
    calloc.free(meanPtr);
    calloc.free(normPtr);
    calloc.free(inputNamePtr);
    calloc.free(outputNamePtr);
    calloc.free(outPtr);

    if (ret != 0) {
      throw StateError('NCNN embedding inference failed (ret=$ret)');
    }

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
    if (_net != null) {
      _bindings.destroyNet(_net!);
      _net = null;
    }
  }
}
