import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'face_detection_service.dart';
import 'inference/face_detector.dart';
import 'inference/face_embedder.dart';
import 'inference/backend_registry.dart';
import 'inference/ncnn/ncnn_bindings.dart';

/// Result of a single backend benchmark run.
class BenchmarkResult {
  final String backendName;
  final String imageSize;
  final int facesDetected;
  final int tilesProcessed;
  final double preprocessMs;
  final double inferenceMs;
  final double postprocessMs;
  final double totalMs;
  final double peakMemoryMb;
  final List<RawDetection> detections;

  BenchmarkResult({
    required this.backendName,
    required this.imageSize,
    required this.facesDetected,
    required this.tilesProcessed,
    required this.preprocessMs,
    required this.inferenceMs,
    required this.postprocessMs,
    required this.totalMs,
    required this.peakMemoryMb,
    required this.detections,
  });
}

class BenchmarkService {
  final BackendRegistry _registry;

  /// Progress callback: (backendName, tileIndex, totalTiles)
  void Function(String backend, int current, int total)? onProgress;

  BenchmarkService(this._registry);

  /// Get native heap allocation in bytes via mallinfo().
  /// Falls back to 0 if NCNN bridge is not available.
  static int _getNativeHeapBytes() {
    final bindings = NcnnBindings.instance;
    if (bindings.isAvailable) {
      return bindings.getNativeHeapBytes();
    }
    return 0;
  }

  /// Run benchmark for a specific backend on a given image.
  /// Runs single-pass detection (no multi-scale tiling) for fair comparison,
  /// then optionally runs tiled detection for real-world measurement.
  Future<BenchmarkResult> runDetectionBenchmark(
    String backendName,
    img.Image image, {
    bool includeTiles = false,
  }) async {
    final heapBefore = _getNativeHeapBytes();

    final detector = _registry.createDetectorFor(backendName);
    await detector.loadModel();

    var peakHeap = _getNativeHeapBytes();

    // Downscale large images for benchmark to avoid excessive tiling
    final benchImage = _prepareForBenchmark(image);
    final rgbBytes = FaceDetectionService.imageToRgbBytes(benchImage);
    final w = benchImage.width;
    final h = benchImage.height;

    double totalPreprocess = 0;
    double totalInference = 0;
    double totalPostprocess = 0;
    int tileCount = 0;

    final sw = Stopwatch()..start();

    // Warm-up run (discard timing)
    onProgress?.call(backendName, 0, includeTiles ? 4 : 3);
    detector.detectSingle(rgbBytes, w, h, scoreThreshold: 0.5);
    final heapAfterWarmup = _getNativeHeapBytes();
    if (heapAfterWarmup > peakHeap) peakHeap = heapAfterWarmup;
    await Future<void>.delayed(Duration.zero); // yield to UI

    // Run 3 times and average for stable results
    final allDetections = <RawDetection>[];
    for (int run = 0; run < 3; run++) {
      onProgress?.call(backendName, run + 1, includeTiles ? 4 : 3);
      await Future<void>.delayed(Duration.zero); // yield to UI

      final result = detector.detectSingle(rgbBytes, w, h, scoreThreshold: 0.5);
      totalPreprocess += result.timing.preprocessMs;
      totalInference += result.timing.inferenceMs;
      totalPostprocess += result.timing.postprocessMs;
      tileCount++;

      final heapNow = _getNativeHeapBytes();
      if (heapNow > peakHeap) peakHeap = heapNow;

      if (run == 2) {
        allDetections.addAll(result.detections);
      }
    }

    // Average over 3 runs
    totalPreprocess /= 3;
    totalInference /= 3;
    totalPostprocess /= 3;

    final deduped = detector.nms(allDetections, 0.4);

    sw.stop();
    final totalMs = totalPreprocess + totalInference + totalPostprocess;

    final peakMemoryMb = (peakHeap > heapBefore ? peakHeap - heapBefore : 0) / (1024.0 * 1024.0);

    detector.dispose();

    return BenchmarkResult(
      backendName: backendName,
      imageSize: '${image.width}x${image.height} -> ${w}x$h',
      facesDetected: deduped.length,
      tilesProcessed: tileCount,
      preprocessMs: totalPreprocess,
      inferenceMs: totalInference,
      postprocessMs: totalPostprocess,
      totalMs: totalMs,
      peakMemoryMb: peakMemoryMb,
      detections: deduped,
    );
  }

  /// Downscale image so the longer side is <= 1280 for benchmark.
  img.Image _prepareForBenchmark(img.Image image) {
    final maxDim = image.width > image.height ? image.width : image.height;
    if (maxDim <= 1280) return image;

    final scale = 1280.0 / maxDim;
    final newW = (image.width * scale).round();
    final newH = (image.height * scale).round();
    return img.copyResize(image, width: newW, height: newH);
  }

  /// Run benchmark for all registered backends.
  Future<List<BenchmarkResult>> runAllBenchmarks(img.Image image) async {
    final results = <BenchmarkResult>[];
    for (final backend in _registry.listBackends()) {
      final result = await runDetectionBenchmark(backend.name, image);
      results.add(result);
    }
    return results;
  }
}
