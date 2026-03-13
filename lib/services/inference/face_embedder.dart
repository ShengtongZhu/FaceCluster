import 'dart:typed_data';

/// Timing breakdown for a single embedding call.
class EmbeddingTiming {
  final double preprocessMs;
  final double inferenceMs;
  final double postprocessMs;

  EmbeddingTiming({
    required this.preprocessMs,
    required this.inferenceMs,
    required this.postprocessMs,
  });

  double get totalMs => preprocessMs + inferenceMs + postprocessMs;
}

/// Result of getEmbedding, including the vector and timing.
class EmbeddingResult {
  final Float32List embedding;
  final EmbeddingTiming timing;

  EmbeddingResult({required this.embedding, required this.timing});
}

/// Abstract interface for face embedding backends.
///
/// Implementations receive raw BGR bytes and handle all preprocessing
/// (normalize, etc.) internally for maximum performance.
abstract class FaceEmbedder {
  /// Human-readable backend name (e.g., "TFLite", "NCNN").
  String get backendName;

  /// Embedding vector dimension (typically 512).
  int get embeddingDim;

  /// Load the embedding model. Must be called before getEmbedding.
  Future<void> loadModel();

  /// Generate a face embedding from an aligned face image.
  ///
  /// [bgrBytes]: Raw BGR pixel data, 3 bytes per pixel, row-major order.
  /// [width], [height]: Image dimensions (typically 112x112).
  ///
  /// Returns L2-normalized embedding vector.
  EmbeddingResult getEmbedding(Uint8List bgrBytes, int width, int height);

  /// Release model resources.
  void dispose();
}
