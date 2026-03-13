import 'face_detector.dart';
import 'face_embedder.dart';

/// Describes an available inference backend.
class BackendInfo {
  final String name;
  final bool isAvailable;

  BackendInfo({required this.name, required this.isAvailable});
}

/// Factory function types for creating backend instances.
typedef FaceDetectorFactory = FaceDetector Function();
typedef FaceEmbedderFactory = FaceEmbedder Function();

/// Registry for inference backends. Manages registration, listing, and switching.
class BackendRegistry {
  final Map<String, FaceDetectorFactory> _detectorFactories = {};
  final Map<String, FaceEmbedderFactory> _embedderFactories = {};

  String? _activeBackend;

  /// Register a backend with its detector and embedder factories.
  void register(
    String name, {
    required FaceDetectorFactory detector,
    required FaceEmbedderFactory embedder,
  }) {
    _detectorFactories[name] = detector;
    _embedderFactories[name] = embedder;
    // Auto-select first registered backend.
    _activeBackend ??= name;
  }

  /// List all registered backends.
  List<BackendInfo> listBackends() {
    return _detectorFactories.keys
        .map((name) => BackendInfo(name: name, isAvailable: true))
        .toList();
  }

  /// Get the currently active backend name.
  String get activeBackend {
    if (_activeBackend == null) {
      throw StateError('No backend registered.');
    }
    return _activeBackend!;
  }

  /// Switch the active backend.
  void setActiveBackend(String name) {
    if (!_detectorFactories.containsKey(name)) {
      throw ArgumentError('Backend "$name" is not registered.');
    }
    _activeBackend = name;
  }

  /// Create a FaceDetector instance for the active backend.
  FaceDetector createDetector() {
    return _detectorFactories[activeBackend]!();
  }

  /// Create a FaceEmbedder instance for the active backend.
  FaceEmbedder createEmbedder() {
    return _embedderFactories[activeBackend]!();
  }

  /// Create a FaceDetector instance for a specific backend (for benchmarking).
  FaceDetector createDetectorFor(String name) {
    if (!_detectorFactories.containsKey(name)) {
      throw ArgumentError('Backend "$name" is not registered.');
    }
    return _detectorFactories[name]!();
  }

  /// Create a FaceEmbedder instance for a specific backend (for benchmarking).
  FaceEmbedder createEmbedderFor(String name) {
    if (!_embedderFactories.containsKey(name)) {
      throw ArgumentError('Backend "$name" is not registered.');
    }
    return _embedderFactories[name]!();
  }
}
