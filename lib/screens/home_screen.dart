import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:drift/drift.dart' hide Column;

import '../models/database.dart';
import '../services/face_detection_service.dart';
import '../services/embedding_service.dart';
import '../services/clustering_service.dart';
import '../services/processing_service.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = AppDatabase.instance;
  late final FaceDetectionService _detectionService;
  late final EmbeddingService _embeddingService;
  late final ClusteringService _clusteringService;
  ProcessingService? _processingService;

  List<Photo> _importedPhotos = [];
  bool _isProcessing = false;
  String _statusMessage = '';
  int _progressCurrent = 0;
  int _progressTotal = 0;
  double _similarityThreshold = 0.4;
  int _minSamples = 1;
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _detectionService = FaceDetectionService();
    _embeddingService = EmbeddingService();
    _clusteringService = ClusteringService();
    _loadModel();
    _loadExistingPhotos();
  }

  Future<void> _loadModel() async {
    try {
      print('[FaceCluster] Loading models...');
      await Future.wait([
        _detectionService.loadDetector(),
        _embeddingService.loadModel(),
      ]);
      print('[FaceCluster] All models loaded successfully');
      setState(() => _modelLoaded = true);
    } catch (e, st) {
      print('[FaceCluster] Failed to load models: $e\n$st');
      setState(() => _statusMessage = 'Failed to load models: $e');
    }
  }

  Future<void> _loadExistingPhotos() async {
    final photos = await _db.getAllPhotos();
    setState(() => _importedPhotos = photos);
  }

  Future<void> _importPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() => _statusMessage = 'Photo library permission denied');
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
    if (albums.isEmpty) {
      setState(() => _statusMessage = 'No albums found');
      return;
    }

    // Show album picker
    final selectedAlbum = await showDialog<AssetPathEntity>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Album'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: albums.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(albums[i].name),
              onTap: () => Navigator.pop(ctx, albums[i]),
            ),
          ),
        ),
      ),
    );

    if (selectedAlbum == null) return;

    setState(() {
      _statusMessage = 'Importing photos...';
      _isProcessing = true;
    });

    // Clear existing data
    await _db.deleteAllPhotos();

    final count = await selectedAlbum.assetCountAsync;
    final assets = await selectedAlbum.getAssetListRange(start: 0, end: count);

    int imported = 0;
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;

      await _db.insertPhoto(PhotosCompanion(
        path: Value(file.path),
        width: Value(asset.width),
        height: Value(asset.height),
        createdAt: Value(asset.createDateTime),
      ));
      imported++;
    }

    final photos = await _db.getAllPhotos();
    setState(() {
      _importedPhotos = photos;
      _statusMessage = 'Imported $imported photos';
      _isProcessing = false;
    });
  }

  Future<void> _startProcessing() async {
    if (_importedPhotos.isEmpty) {
      setState(() => _statusMessage = 'No photos to process');
      return;
    }

    if (!_modelLoaded) {
      setState(() => _statusMessage = 'Model not loaded yet');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
    });

    _processingService = ProcessingService(
      db: _db,
      detectionService: _detectionService,
      embeddingService: _embeddingService,
      clusteringService: _clusteringService,
    );

    _processingService!.onProgress = (stage, current, total) {
      setState(() {
        _progressCurrent = current;
        _progressTotal = total;
        switch (stage) {
          case 'detection':
            _statusMessage = 'Detecting faces: $current/$total photos';
            break;
          case 'embedding':
            _statusMessage = 'Generating embeddings: $current/$total faces';
            break;
          case 'clustering':
            _statusMessage = 'Clustering faces...';
            break;
          case 'done':
            _statusMessage = 'Processing complete!';
            break;
        }
      });
    };

    try {
      await _processingService!.processPhotos(
        photos: _importedPhotos,
        similarityThreshold: _similarityThreshold,
        minSamples: _minSamples,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              stats: _processingService!.stats,
              similarityThreshold: _similarityThreshold,
              minSamples: _minSamples,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _detectionService.dispose();
    _embeddingService.dispose();
    _processingService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FaceCluster'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _modelLoaded ? 'Model loaded' : 'Loading model...',
                      style: TextStyle(
                        color: _modelLoaded ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Photos: ${_importedPhotos.length}'),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_statusMessage),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Import button
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _importPhotos,
              icon: const Icon(Icons.photo_library),
              label: const Text('Import Photos'),
            ),

            const SizedBox(height: 16),

            // Parameters
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clustering Parameters',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Similarity Threshold: ${_similarityThreshold.toStringAsFixed(2)}',
                    ),
                    Slider(
                      value: _similarityThreshold,
                      min: 0.4,
                      max: 0.8,
                      divisions: 40,
                      onChanged: _isProcessing
                          ? null
                          : (v) => setState(() => _similarityThreshold = v),
                    ),
                    Text('Min Samples: $_minSamples'),
                    Slider(
                      value: _minSamples.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: _isProcessing
                          ? null
                          : (v) => setState(() => _minSamples = v.toInt()),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Process button
            ElevatedButton.icon(
              onPressed:
                  (_isProcessing || _importedPhotos.isEmpty || !_modelLoaded)
                      ? null
                      : _startProcessing,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Processing'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progressTotal > 0
                    ? _progressCurrent / _progressTotal
                    : null,
              ),
            ],

            // Photo preview
            if (_importedPhotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Imported Photos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _importedPhotos.length,
                  itemBuilder: (ctx, i) {
                    final photo = _importedPhotos[i];
                    return Image.file(
                      File(photo.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
