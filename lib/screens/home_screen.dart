import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:drift/drift.dart' hide Column;

import '../models/database.dart';
import '../services/face_detection_service.dart';
import '../services/inference/face_embedder.dart';
import '../services/inference/backend_registry.dart';
import '../services/clustering_service.dart';
import '../services/processing_service.dart';
import 'photo_selection_screen.dart';
import 'results_screen.dart';

class ClusterTab extends StatefulWidget {
  final BackendRegistry registry;

  const ClusterTab({super.key, required this.registry});

  @override
  State<ClusterTab> createState() => _ClusterTabState();
}

class _ClusterTabState extends State<ClusterTab> {
  final _db = AppDatabase.instance;
  late FaceDetectionService _detectionService;
  late FaceEmbedder _embedder;
  late final ClusteringService _clusteringService;
  ProcessingService? _processingService;
  late String _selectedBackend;

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
    _selectedBackend = widget.registry.activeBackend;
    _detectionService = FaceDetectionService(widget.registry.createDetector());
    _embedder = widget.registry.createEmbedder();
    _clusteringService = ClusteringService();
    _loadModel();
    _loadExistingPhotos();
  }

  Future<void> _switchBackend(String name) async {
    if (name == _selectedBackend) return;
    _detectionService.dispose();
    _embedder.dispose();
    widget.registry.setActiveBackend(name);
    _detectionService = FaceDetectionService(widget.registry.createDetector());
    _embedder = widget.registry.createEmbedder();
    setState(() {
      _selectedBackend = name;
      _modelLoaded = false;
      _statusMessage = 'Switching to $name...';
    });
    await _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      print('[FaceCluster] Loading $activeBackend models...');
      await Future.wait([
        _detectionService.loadDetector(),
        _embedder.loadModel(),
      ]);
      print('[FaceCluster] $activeBackend models loaded successfully');
      setState(() => _modelLoaded = true);
    } catch (e, st) {
      print('[FaceCluster] Failed to load models: $e\n$st');
      setState(() => _statusMessage = 'Failed to load models: $e');
    }
  }

  String get activeBackend => _selectedBackend;

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

    // Step 1: Album picker
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

    if (selectedAlbum == null || !mounted) return;

    // Step 2: Photo selection screen
    final selectedAssets = await Navigator.push<List<AssetEntity>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoSelectionScreen(album: selectedAlbum),
      ),
    );

    if (selectedAssets == null || selectedAssets.isEmpty) return;

    setState(() {
      _statusMessage = 'Importing ${selectedAssets.length} photos...';
      _isProcessing = true;
    });

    // Clear existing data
    await _db.deleteAllPhotos();

    int imported = 0;
    for (final asset in selectedAssets) {
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
      embedder: _embedder,
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
    _embedder.dispose();
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
            // Status + Backend selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Backend selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Engine: ',
                            style: TextStyle(fontSize: 13)),
                        SegmentedButton<String>(
                          segments: widget.registry
                              .listBackends()
                              .map((b) => ButtonSegment(
                                    value: b.name,
                                    label: Text(b.name),
                                  ))
                              .toList(),
                          selected: {_selectedBackend},
                          onSelectionChanged: _isProcessing
                              ? null
                              : (s) => _switchBackend(s.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _modelLoaded
                          ? '$_selectedBackend model loaded'
                          : 'Loading $_selectedBackend model...',
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

            // Parameters — compact ExpansionTile
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Clustering Parameters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  'Threshold: ${_similarityThreshold.toStringAsFixed(2)}, Min: $_minSamples',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                initiallyExpanded: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                              : (v) =>
                                  setState(() => _similarityThreshold = v),
                        ),
                        Text('Min Samples: $_minSamples'),
                        Slider(
                          value: _minSamples.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          onChanged: _isProcessing
                              ? null
                              : (v) =>
                                  setState(() => _minSamples = v.toInt()),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
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
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
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
