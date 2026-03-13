import 'dart:io';

class PerfStats {
  Duration detectionTime = Duration.zero;
  Duration embeddingTime = Duration.zero;
  Duration clusteringTime = Duration.zero;
  int totalPhotos = 0;
  int totalFaces = 0;
  int clusterCount = 0;
  int peakMemoryBytes = 0;

  Duration get totalTime => detectionTime + embeddingTime + clusteringTime;

  double get avgTimePerPhotoMs {
    if (totalPhotos == 0) return 0;
    return totalTime.inMilliseconds / totalPhotos;
  }

  double get peakMemoryMB => peakMemoryBytes / (1024 * 1024);

  void updatePeakMemory() {
    final info = ProcessInfo.currentRss;
    if (info > peakMemoryBytes) {
      peakMemoryBytes = info;
    }
  }

  void reset() {
    detectionTime = Duration.zero;
    embeddingTime = Duration.zero;
    clusteringTime = Duration.zero;
    totalPhotos = 0;
    totalFaces = 0;
    clusterCount = 0;
    peakMemoryBytes = 0;
  }
}
