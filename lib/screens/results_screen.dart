import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/database.dart';
import '../services/perf_stats.dart';
import '../services/clustering_service.dart';
import 'person_detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  final PerfStats stats;
  final double similarityThreshold;
  final int minSamples;

  const ResultsScreen({
    super.key,
    required this.stats,
    required this.similarityThreshold,
    required this.minSamples,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _db = AppDatabase.instance;
  final _clusteringService = ClusteringService();

  Map<int, List<Face>> _clusters = {};
  List<Face> _unclustered = [];
  bool _isLoading = true;
  late double _threshold;
  late int _minSamples;
  late PerfStats _stats;

  @override
  void initState() {
    super.initState();
    _threshold = widget.similarityThreshold;
    _minSamples = widget.minSamples;
    _stats = widget.stats;
    _loadClusters();
  }

  Future<void> _loadClusters() async {
    setState(() => _isLoading = true);

    final allFaces = await _db.getAllFaces();
    final clusters = <int, List<Face>>{};
    final unclustered = <Face>[];

    for (final face in allFaces) {
      if (face.clusterId <= 0) {
        unclustered.add(face);
      } else {
        clusters.putIfAbsent(face.clusterId, () => []).add(face);
      }
    }

    setState(() {
      _clusters = clusters;
      _unclustered = unclustered;
      _isLoading = false;
    });
  }

  Future<void> _recluster() async {
    setState(() => _isLoading = true);

    final allFaces = await _db.getAllFaces();
    final embeddings = <Float32List>[];
    final faceIds = <int>[];

    for (final face in allFaces) {
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
      similarityThreshold: _threshold,
      minSamples: _minSamples,
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
    _stats.clusteringTime = stopwatch.elapsed;
    _stats.clusterCount = result.clusterCount;

    await _loadClusters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showStats,
            tooltip: 'Performance Stats',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Re-cluster controls
                Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Threshold: ${_threshold.toStringAsFixed(2)}',
                        ),
                        Slider(
                          value: _threshold,
                          min: 0.4,
                          max: 0.8,
                          divisions: 40,
                          onChanged: (v) => setState(() => _threshold = v),
                        ),
                        Text('Min Samples: $_minSamples'),
                        Slider(
                          value: _minSamples.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          onChanged: (v) =>
                              setState(() => _minSamples = v.toInt()),
                        ),
                        Center(
                          child: ElevatedButton(
                            onPressed: _recluster,
                            child: const Text('Re-cluster'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_clusters.length} person groups, ${_unclustered.length} unclustered',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Cluster list
                Expanded(
                  child: ListView(
                    children: [
                      ..._clusters.entries.map((entry) {
                        final faces = entry.value;
                        final representativeFace = faces.first;
                        return _buildClusterTile(
                          'Person ${entry.key}',
                          faces,
                          representativeFace,
                        );
                      }),
                      if (_unclustered.isNotEmpty)
                        _buildClusterTile(
                          'Unclustered',
                          _unclustered,
                          _unclustered.first,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildClusterTile(
      String title, List<Face> faces, Face representativeFace) {
    return ListTile(
      leading: FutureBuilder<Photo?>(
        future: _getPhotoForFace(representativeFace),
        builder: (ctx, snapshot) {
          if (snapshot.data == null) {
            return const SizedBox(width: 48, height: 48);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Image.file(
                File(snapshot.data!.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.face),
              ),
            ),
          );
        },
      ),
      title: Text(title),
      subtitle: Text('${faces.length} faces'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonDetailScreen(
              title: title,
              faces: faces,
            ),
          ),
        );
      },
    );
  }

  Future<Photo?> _getPhotoForFace(Face face) async {
    final photos = await _db.getAllPhotos();
    try {
      return photos.firstWhere((p) => p.id == face.photoId);
    } catch (_) {
      return null;
    }
  }

  void _showStats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Performance Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statRow('Total Photos', '${_stats.totalPhotos}'),
            _statRow('Total Faces', '${_stats.totalFaces}'),
            _statRow('Person Groups', '${_stats.clusterCount}'),
            const Divider(),
            _statRow('Detection', '${_stats.detectionTime.inMilliseconds} ms'),
            _statRow('Embedding', '${_stats.embeddingTime.inMilliseconds} ms'),
            _statRow(
                'Clustering', '${_stats.clusteringTime.inMilliseconds} ms'),
            _statRow('Total', '${_stats.totalTime.inMilliseconds} ms'),
            const Divider(),
            _statRow(
                'Avg/Photo', '${_stats.avgTimePerPhotoMs.toStringAsFixed(1)} ms'),
            _statRow(
                'Peak Memory', '${_stats.peakMemoryMB.toStringAsFixed(1)} MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
