import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:image/image.dart' as img;

import '../models/database.dart';
import 'face_detection_service.dart';
import 'embedding_service.dart';
import 'clustering_service.dart';
import 'perf_stats.dart';

class ProcessingService {
  final AppDatabase _db;
  final FaceDetectionService _detectionService;
  final EmbeddingService _embeddingService;
  final ClusteringService _clusteringService;
  final PerfStats stats = PerfStats();

  ProcessingService({
    required AppDatabase db,
    required FaceDetectionService detectionService,
    required EmbeddingService embeddingService,
    required ClusteringService clusteringService,
  })  : _db = db,
        _detectionService = detectionService,
        _embeddingService = embeddingService,
        _clusteringService = clusteringService;

  /// Callback for progress updates: (stage, current, total)
  void Function(String stage, int current, int total)? onProgress;

  Future<void> processPhotos({
    required List<Photo> photos,
    double similarityThreshold = 0.6,
    int minSamples = 2,
  }) async {
    stats.reset();
    stats.totalPhotos = photos.length;
    stats.updatePeakMemory();

    // Stage 1: Face Detection
    final stopwatch = Stopwatch()..start();
    final allFaceIds = <int>[];

    for (int i = 0; i < photos.length; i++) {
      onProgress?.call('detection', i + 1, photos.length);

      final detectedFaces =
          await _detectionService.detectFaces(photos[i].path);

      for (final face in detectedFaces) {
        final faceId = await _db.insertFace(FacesCompanion(
          photoId: Value(photos[i].id),
          bboxX: Value(face.bboxX),
          bboxY: Value(face.bboxY),
          bboxW: Value(face.bboxW),
          bboxH: Value(face.bboxH),
        ));
        allFaceIds.add(faceId);

        // Store aligned face temporarily for embedding
        _alignedFaces[faceId] = face.alignedFace;
      }

      stats.updatePeakMemory();
    }

    stopwatch.stop();
    stats.detectionTime = stopwatch.elapsed;
    stats.totalFaces = allFaceIds.length;

    // Stage 2: Embedding Generation
    stopwatch
      ..reset()
      ..start();

    final embeddings = <Float32List>[];

    for (int i = 0; i < allFaceIds.length; i++) {
      onProgress?.call('embedding', i + 1, allFaceIds.length);

      final faceId = allFaceIds[i];
      final alignedFace = _alignedFaces[faceId]!;

      final embedding = _embeddingService.getEmbedding(alignedFace);
      embeddings.add(embedding);

      // Store embedding as bytes
      final bytes = embedding.buffer.asUint8List();
      await _db.updateFaceEmbedding(faceId, Uint8List.fromList(bytes));

      // Free aligned face image from memory
      _alignedFaces.remove(faceId);

      stats.updatePeakMemory();
    }

    stopwatch.stop();
    stats.embeddingTime = stopwatch.elapsed;

    // Stage 3: Clustering
    stopwatch
      ..reset()
      ..start();

    onProgress?.call('clustering', 0, 1);

    final result = _clusteringService.cluster(
      embeddings: embeddings,
      similarityThreshold: similarityThreshold,
      minSamples: minSamples,
    );

    // Update cluster IDs in database
    for (final entry in result.clusters.entries) {
      for (final faceIdx in entry.value) {
        await _db.updateFaceClusterId(allFaceIds[faceIdx], entry.key);
      }
    }
    for (final faceIdx in result.noise) {
      await _db.updateFaceClusterId(allFaceIds[faceIdx], -1);
    }

    stopwatch.stop();
    stats.clusteringTime = stopwatch.elapsed;
    stats.clusterCount = result.clusterCount;

    onProgress?.call('done', 1, 1);
    stats.updatePeakMemory();
  }

  /// Re-cluster with new parameters without re-detecting or re-embedding
  Future<void> recluster({
    double similarityThreshold = 0.6,
    int minSamples = 2,
  }) async {
    final faces = await _db.getAllFaces();
    if (faces.isEmpty) return;

    final embeddings = <Float32List>[];
    final faceIds = <int>[];

    for (final face in faces) {
      if (face.embedding == null) continue;
      final floats = Float32List.view(
        Uint8List.fromList(face.embedding!).buffer,
      );
      embeddings.add(floats);
      faceIds.add(face.id);
    }

    final stopwatch = Stopwatch()..start();

    final result = _clusteringService.cluster(
      embeddings: embeddings,
      similarityThreshold: similarityThreshold,
      minSamples: minSamples,
    );

    await _db.resetAllClusterIds();

    for (final entry in result.clusters.entries) {
      for (final faceIdx in entry.value) {
        await _db.updateFaceClusterId(faceIds[faceIdx], entry.key);
      }
    }
    for (final faceIdx in result.noise) {
      await _db.updateFaceClusterId(faceIds[faceIdx], -1);
    }

    stopwatch.stop();
    stats.clusteringTime = stopwatch.elapsed;
    stats.clusterCount = result.clusterCount;
  }

  // Temporary storage for aligned face images during processing
  final Map<int, img.Image> _alignedFaces = {};

  void dispose() {
    _alignedFaces.clear();
  }
}
