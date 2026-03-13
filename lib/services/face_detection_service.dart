import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

import 'scrfd_service.dart';

class DetectedFace {
  final double bboxX;
  final double bboxY;
  final double bboxW;
  final double bboxH;
  final img.Image alignedFace;

  DetectedFace({
    required this.bboxX,
    required this.bboxY,
    required this.bboxW,
    required this.bboxH,
    required this.alignedFace,
  });
}

// InsightFace arcface standard template coordinates for 112x112
const _templatePoints = [
  [38.2946, 51.6963], // left eye
  [73.5318, 51.5014], // right eye
  [56.0252, 71.7366], // nose tip
  [41.5493, 92.3655], // left mouth corner
  [70.7299, 92.2041], // right mouth corner
];

class FaceDetectionService {
  final SCRFDService _scrfd = SCRFDService();

  Future<void> loadDetector() async {
    await _scrfd.loadModel();
  }

  Future<List<DetectedFace>> detectFaces(String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    var fullImage = img.decodeImage(imageBytes);
    if (fullImage == null) return [];

    // Apply EXIF orientation
    fullImage = img.bakeOrientation(fullImage);

    final imageWidth = fullImage.width.toDouble();
    final imageHeight = fullImage.height.toDouble();

    // Run multi-scale SCRFD detection
    final faces = _detectMultiScale(fullImage);
    print('[FaceCluster] Detected ${faces.length} faces in ${fullImage.width}x${fullImage.height} image');

    final results = <DetectedFace>[];

    for (final face in faces) {
      // Quality gate: skip tiny faces
      if (face.width < 40 || face.height < 40) {
        print('[FaceCluster] Skipping tiny face: ${face.width.toInt()}x${face.height.toInt()}');
        continue;
      }

      // Quality gate: check eye distance
      final le = face.keypoints[0]; // left eye
      final re = face.keypoints[1]; // right eye
      final dx = re[0] - le[0];
      final dy = re[1] - le[1];
      final eyeDist = sqrt(dx * dx + dy * dy);

      if (eyeDist < 15) {
        print('[FaceCluster] Skipping face: eye_dist=${eyeDist.toStringAsFixed(1)} < 15px');
        continue;
      }

      final ratio = eyeDist / face.width;
      if (ratio < 0.25) {
        print('[FaceCluster] Skipping face: eye_dist/width=${ratio.toStringAsFixed(2)} < 0.25');
        continue;
      }

      // Align using all 5 keypoints with similarity transform
      final aligned = _applySimilarityTransformLeastSquares(
        fullImage,
        face.keypoints,
        _templatePoints,
      );
      if (aligned == null) continue;

      final normX = face.x1 / imageWidth;
      final normY = face.y1 / imageHeight;
      final normW = face.width / imageWidth;
      final normH = face.height / imageHeight;

      results.add(DetectedFace(
        bboxX: normX,
        bboxY: normY,
        bboxW: normW,
        bboxH: normH,
        alignedFace: aligned,
      ));
    }

    return results;
  }

  /// Multi-scale detection: full image + tiled detection for large images.
  /// Ensures faces >= ~40px in the original image can be detected.
  List<SCRFDFace> _detectMultiScale(img.Image image) {
    final allFaces = <SCRFDFace>[];

    // Level 0: full image detection (catches large faces)
    final fullFaces = _scrfd.detect(image, scoreThreshold: 0.5);
    allFaces.addAll(fullFaces);
    print('[FaceCluster] Full-image pass: ${fullFaces.length} faces');

    // Level 1: tiled detection for images where scale < 0.5
    // At scale 0.5, SCRFD can detect ~20px faces → 40px in original
    final maxDim = max(image.width, image.height);
    if (maxDim > 1280) {
      // Tile size chosen so each tile has scale ~0.5 at 640 input
      const tileSize = 1280;
      const overlap = 320; // 25% overlap to catch boundary faces
      const stride = tileSize - overlap; // 960

      int tileCount = 0;
      int tileFaceCount = 0;

      for (int y0 = 0; y0 < image.height; y0 += stride) {
        for (int x0 = 0; x0 < image.width; x0 += stride) {
          final x1 = min(x0 + tileSize, image.width);
          final y1 = min(y0 + tileSize, image.height);
          final w = x1 - x0;
          final h = y1 - y0;

          // Skip tiles that are too small for meaningful detection
          if (w < 320 || h < 320) continue;

          final tile = img.copyCrop(image, x: x0, y: y0, width: w, height: h);
          final tileFaces = _scrfd.detect(tile, scoreThreshold: 0.5);

          // Map tile-local coordinates back to original image coordinates
          for (final f in tileFaces) {
            allFaces.add(SCRFDFace(
              x1: f.x1 + x0,
              y1: f.y1 + y0,
              x2: f.x2 + x0,
              y2: f.y2 + y0,
              score: f.score,
              keypoints: f.keypoints
                  .map((kp) => [kp[0] + x0, kp[1] + y0])
                  .toList(),
            ));
          }

          tileCount++;
          tileFaceCount += tileFaces.length;
        }
      }

      print('[FaceCluster] Tiled detection: $tileFaceCount faces from $tileCount tiles');
    }

    // Global NMS to remove duplicate detections across scales/tiles
    final deduped = _scrfd.nms(allFaces, 0.4);
    print('[FaceCluster] After NMS: ${deduped.length} unique faces');
    return deduped;
  }

  /// Apply least-squares similarity transform (rotation + uniform scale + translation).
  /// Uses all available source/destination point pairs for best fit.
  img.Image? _applySimilarityTransformLeastSquares(
    img.Image src,
    List<List<double>> srcPts,
    List<List<double>> dstPts,
  ) {
    final n = srcPts.length;

    // Build normal equations for similarity transform:
    // x' = a*x - b*y + tx, y' = b*x + a*y + ty
    double ata00 = 0, ata02 = 0, ata03 = 0;
    double ata11 = 0, ata12 = 0, ata13 = 0;
    double ata22 = 0, ata33 = 0;
    double atb0 = 0, atb1 = 0, atb2 = 0, atb3 = 0;

    for (int i = 0; i < n; i++) {
      final x = srcPts[i][0], y = srcPts[i][1];
      final xp = dstPts[i][0], yp = dstPts[i][1];

      ata00 += x * x + y * y;
      ata02 += x;
      ata03 += y;
      ata11 += x * x + y * y;
      ata12 += -y;
      ata13 += x;
      ata22 += 1;
      ata33 += 1;

      atb0 += x * xp + y * yp;
      atb1 += -y * xp + x * yp;
      atb2 += xp;
      atb3 += yp;
    }

    // Solve 4x4 system via Gaussian elimination with partial pivoting
    final mat = [
      [ata00, 0.0, ata02, ata03, atb0],
      [0.0, ata11, ata12, ata13, atb1],
      [ata02, ata12, ata22, 0.0, atb2],
      [ata03, ata13, 0.0, ata33, atb3],
    ];

    for (int col = 0; col < 4; col++) {
      int maxRow = col;
      double maxVal = mat[col][col].abs();
      for (int row = col + 1; row < 4; row++) {
        if (mat[row][col].abs() > maxVal) {
          maxVal = mat[row][col].abs();
          maxRow = row;
        }
      }
      if (maxVal < 1e-10) return null;
      if (maxRow != col) {
        final tmp = mat[col];
        mat[col] = mat[maxRow];
        mat[maxRow] = tmp;
      }
      for (int row = col + 1; row < 4; row++) {
        final factor = mat[row][col] / mat[col][col];
        for (int j = col; j < 5; j++) {
          mat[row][j] -= factor * mat[col][j];
        }
      }
    }

    final params = List<double>.filled(4, 0);
    for (int row = 3; row >= 0; row--) {
      double sum = mat[row][4];
      for (int j = row + 1; j < 4; j++) {
        sum -= mat[row][j] * params[j];
      }
      params[row] = sum / mat[row][row];
    }

    final a = params[0], b = params[1], tx = params[2], ty = params[3];

    // Inverse similarity transform for pixel mapping
    final det = a * a + b * b;
    if (det < 1e-10) return null;

    final invA = a / det;
    final invB = b / det;
    final invTx = -(invA * tx + invB * ty);
    final invTy = -((-invB) * tx + invA * ty);

    final result = img.Image(width: 112, height: 112);

    for (int dy = 0; dy < 112; dy++) {
      for (int dx = 0; dx < 112; dx++) {
        final srcX = invA * dx + invB * dy + invTx;
        final srcY = (-invB) * dx + invA * dy + invTy;
        result.setPixel(dx, dy, _bilinearSample(src, srcX, srcY));
      }
    }

    return result;
  }

  /// Bilinear interpolation sampling from source image.
  img.Color _bilinearSample(img.Image src, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    if (x0 < 0 || y0 < 0 || x1 >= src.width || y1 >= src.height) {
      return img.ColorRgb8(0, 0, 0);
    }

    final fx = x - x0;
    final fy = y - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    final r = _blerp(p00.r, p10.r, p01.r, p11.r, fx, fy);
    final g = _blerp(p00.g, p10.g, p01.g, p11.g, fx, fy);
    final bv = _blerp(p00.b, p10.b, p01.b, p11.b, fx, fy);

    return img.ColorRgb8(
        r.round().clamp(0, 255), g.round().clamp(0, 255), bv.round().clamp(0, 255));
  }

  double _blerp(num c00, num c10, num c01, num c11, double fx, double fy) {
    final top = c00.toDouble() * (1 - fx) + c10.toDouble() * fx;
    final bot = c01.toDouble() * (1 - fx) + c11.toDouble() * fx;
    return top * (1 - fy) + bot * fy;
  }

  void dispose() {
    _scrfd.dispose();
  }
}
