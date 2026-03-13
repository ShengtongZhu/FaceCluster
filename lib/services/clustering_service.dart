import 'dart:typed_data';
import 'dart:math' as math;

class ClusterResult {
  final Map<int, List<int>> clusters; // clusterId -> list of face indices
  final List<int> noise; // face indices not in any cluster

  ClusterResult({required this.clusters, required this.noise});

  int get clusterCount => clusters.length;
}

class ClusteringService {
  /// Run DBSCAN on face embeddings.
  /// [embeddings] - list of 512-dim float32 vectors
  /// [similarityThreshold] - cosine similarity threshold (0.4-0.8)
  /// [minSamples] - minimum number of faces to form a cluster
  ClusterResult cluster({
    required List<Float32List> embeddings,
    double similarityThreshold = 0.6,
    int minSamples = 2,
  }) {
    final n = embeddings.length;
    if (n == 0) return ClusterResult(clusters: {}, noise: []);

    // Convert similarity threshold to distance threshold
    // cosine distance = 1 - cosine similarity
    final eps = 1.0 - similarityThreshold;

    // DBSCAN labels: -1 = unvisited, 0 = noise, >0 = cluster id
    final labels = List.filled(n, -1);
    int currentCluster = 0;

    for (int i = 0; i < n; i++) {
      if (labels[i] != -1) continue;

      final neighbors = _regionQuery(embeddings, i, eps);

      if (neighbors.length < minSamples) {
        labels[i] = 0; // noise
        continue;
      }

      currentCluster++;
      labels[i] = currentCluster;

      final seedSet = List<int>.from(neighbors);
      int j = 0;

      while (j < seedSet.length) {
        final q = seedSet[j];

        if (labels[q] == 0) {
          labels[q] = currentCluster; // was noise, now border point
        }

        if (labels[q] != -1) {
          j++;
          continue;
        }

        labels[q] = currentCluster;

        final qNeighbors = _regionQuery(embeddings, q, eps);
        if (qNeighbors.length >= minSamples) {
          for (final neighbor in qNeighbors) {
            if (!seedSet.contains(neighbor)) {
              seedSet.add(neighbor);
            }
          }
        }

        j++;
      }
    }

    // Build result
    final clusters = <int, List<int>>{};
    final noise = <int>[];

    for (int i = 0; i < n; i++) {
      if (labels[i] <= 0) {
        noise.add(i);
      } else {
        clusters.putIfAbsent(labels[i], () => []).add(i);
      }
    }

    return ClusterResult(clusters: clusters, noise: noise);
  }

  List<int> _regionQuery(List<Float32List> embeddings, int pointIdx, double eps) {
    final neighbors = <int>[];
    final point = embeddings[pointIdx];

    for (int i = 0; i < embeddings.length; i++) {
      if (i == pointIdx) continue;
      final distance = _cosineDistance(point, embeddings[i]);
      if (distance <= eps) {
        neighbors.add(i);
      }
    }

    return neighbors;
  }

  double _cosineDistance(Float32List a, Float32List b) {
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 1.0;

    final similarity = dotProduct / (math.sqrt(normA) * math.sqrt(normB));
    return 1.0 - similarity;
  }
}
