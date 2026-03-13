import 'dart:io';
import 'dart:math';
import 'dart:typed_data' as typed_data;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

import '../services/benchmark_service.dart';
import '../services/inference/backend_registry.dart';
import '../services/inference/face_detector.dart';

class BenchmarkScreen extends StatefulWidget {
  final BackendRegistry registry;
  final String? testImagePath;

  const BenchmarkScreen({
    super.key,
    required this.registry,
    this.testImagePath,
  });

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  List<BenchmarkResult> _results = [];
  bool _isRunning = false;
  String _status = '';
  String? _selectedImagePath;
  File? _selectedImageFile;
  int _benchImageW = 0;
  int _benchImageH = 0;

  @override
  void initState() {
    super.initState();
    _selectedImagePath = widget.testImagePath;
    if (_selectedImagePath != null) {
      _selectedImageFile = File(_selectedImagePath!);
    }
  }

  Future<void> _pickImage() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) {
        setState(() => _status = 'Photo permission denied');
      }
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
      ),
    );

    if (albums.isEmpty) {
      if (mounted) setState(() => _status = 'No photo albums found');
      return;
    }

    // Get recent photos from the first album (Camera Roll / All Photos)
    final recentPhotos = await albums.first.getAssetListRange(start: 0, end: 50);

    if (!mounted) return;

    final selected = await showModalBottomSheet<AssetEntity>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Select Test Photo',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: recentPhotos.length,
                itemBuilder: (_, i) {
                  final asset = recentPhotos[i];
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, asset),
                    child: FutureBuilder<typed_data.Uint8List?>(
                      future: asset.thumbnailDataWithSize(
                        const ThumbnailSize.square(200),
                      ),
                      builder: (_, snap) {
                        if (snap.data == null) {
                          return Container(color: Colors.grey.shade200);
                        }
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    final file = await selected.file;
    if (file == null) return;

    setState(() {
      _selectedImagePath = file.path;
      _selectedImageFile = file;
      _results = [];
      _status = '';
    });
  }

  Future<void> _runBenchmark() async {
    if (_selectedImagePath == null) {
      setState(() => _status = 'Please select an image first');
      return;
    }

    setState(() {
      _isRunning = true;
      _results = [];
      _status = 'Loading image...';
    });

    try {
      final bytes = await File(_selectedImagePath!).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        setState(() {
          _isRunning = false;
          _status = 'Failed to decode image';
        });
        return;
      }
      image = img.bakeOrientation(image);

      final benchmarkService = BenchmarkService(widget.registry);
      benchmarkService.onProgress = (backend, current, total) {
        setState(() => _status = '$backend: run $current/$total...');
      };
      final backends = widget.registry.listBackends();
      final results = <BenchmarkResult>[];

      for (int i = 0; i < backends.length; i++) {
        setState(() => _status = 'Running ${backends[i].name} (${i + 1}/${backends.length})...');
        await Future<void>.delayed(Duration.zero);
        final result = await benchmarkService.runDetectionBenchmark(
          backends[i].name,
          image!,
        );
        results.add(result);
      }

      // Parse bench image dimensions from first result's imageSize "WxH -> WxH"
      if (results.isNotEmpty) {
        final parts = results.first.imageSize.split(' -> ');
        if (parts.length == 2) {
          final dims = parts[1].split('x');
          _benchImageW = int.tryParse(dims[0]) ?? 0;
          _benchImageH = int.tryParse(dims[1]) ?? 0;
        }
      }

      setState(() {
        _results = results;
        _isRunning = false;
        _status = 'Benchmark complete!';
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benchmark'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image picker + Run button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Image',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    // Thumbnail preview + file name
                    if (_selectedImageFile != null)
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImageFile!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedImagePath!.split('/').last,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('No image selected',
                          style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isRunning ? null : _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Select Photo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _runBenchmark,
                            icon: const Icon(Icons.speed),
                            label: const Text('Run'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Status
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14)),
              ),

            if (_isRunning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),

            // Results
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetectionComparison(),
              const SizedBox(height: 16),
              _buildTimingChart(),
              const SizedBox(height: 16),
              _buildMemoryChart(),
              const SizedBox(height: 16),
              _buildDetailTable(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionComparison() {
    if (_selectedImageFile == null || _benchImageW == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detection Results',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Side-by-side (or stacked) detection images
            ..._results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.backendName} — ${r.facesDetected} faces',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final displayW = constraints.maxWidth;
                        final displayH = displayW * _benchImageH / _benchImageW;
                        return SizedBox(
                          width: displayW,
                          height: displayH,
                          child: Stack(
                            children: [
                              Image.file(
                                _selectedImageFile!,
                                width: displayW,
                                height: displayH,
                                fit: BoxFit.cover,
                              ),
                              CustomPaint(
                                size: Size(displayW, displayH),
                                painter: _DetectionPainter(
                                  detections: r.detections,
                                  imageW: _benchImageW,
                                  imageH: _benchImageH,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingChart() {
    final maxTotal = _results.map((r) => r.totalMs).reduce(max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detection Timing (ms)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._results.map((r) => _buildTimingBar(r, maxTotal)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.blue.shade300, 'Preprocess'),
                const SizedBox(width: 12),
                _legendItem(Colors.orange.shade300, 'Inference'),
                const SizedBox(width: 12),
                _legendItem(Colors.green.shade300, 'Postprocess'),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Preprocess: Resize to 640x640 + normalize pixels\n'
              'Inference: Neural network forward pass\n'
              'Postprocess: Decode anchors + NMS filtering',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingBar(BenchmarkResult r, double maxTotal) {
    final total = r.preprocessMs + r.inferenceMs + r.postprocessMs;
    final barWidth = maxTotal > 0 ? total / maxTotal : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r.backendName,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${total.toStringAsFixed(1)} ms',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 24,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth * barWidth;
                  final preW = total > 0 ? width * r.preprocessMs / total : 0.0;
                  final infW = total > 0 ? width * r.inferenceMs / total : 0.0;
                  final postW = total > 0 ? width * r.postprocessMs / total : 0.0;
                  return Row(
                    children: [
                      Container(width: preW, color: Colors.blue.shade300),
                      Container(width: infW, color: Colors.orange.shade300),
                      Container(width: postW, color: Colors.green.shade300),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryChart() {
    final maxMem =
        _results.map((r) => r.peakMemoryMb).reduce(max).clamp(1.0, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Native Heap (MB)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._results.map((r) {
              final barWidth = r.peakMemoryMb / maxMem;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r.backendName,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('${r.peakMemoryMb.toStringAsFixed(1)} MB',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 24,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              width: constraints.maxWidth * barWidth,
                              color: Colors.purple.shade300,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._results.map((r) {
              final total = r.preprocessMs + r.inferenceMs + r.postprocessMs;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.backendName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    _detailRow('Image', r.imageSize),
                    _detailRow('Faces', '${r.facesDetected}'),
                    _detailRow('Preprocess', '${r.preprocessMs.toStringAsFixed(1)} ms'),
                    _detailRow('Inference', '${r.inferenceMs.toStringAsFixed(1)} ms'),
                    _detailRow('Postprocess', '${r.postprocessMs.toStringAsFixed(1)} ms'),
                    const Divider(height: 12),
                    _detailRow('Total', '${total.toStringAsFixed(1)} ms',
                        bold: true),
                    _detailRow('Memory', '${r.peakMemoryMb.toStringAsFixed(1)} MB'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          )),
          Text(value, style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<RawDetection> detections;
  final int imageW;
  final int imageH;

  _DetectionPainter({
    required this.detections,
    required this.imageW,
    required this.imageH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageW;
    final scaleY = size.height / imageH;

    final boxPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: Colors.green,
      fontSize: 11,
      background: Paint()..color = Colors.black54,
    );

    for (final d in detections) {
      final rect = Rect.fromLTRB(
        d.x1 * scaleX,
        d.y1 * scaleY,
        d.x2 * scaleX,
        d.y2 * scaleY,
      );
      canvas.drawRect(rect, boxPaint);

      // Score label
      final tp = TextPainter(
        text: TextSpan(text: ' ${d.score.toStringAsFixed(2)} ', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height));

      // Keypoints
      for (final kp in d.keypoints) {
        canvas.drawCircle(
          Offset(kp[0] * scaleX, kp[1] * scaleY),
          2.5,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      detections != oldDelegate.detections;
}
