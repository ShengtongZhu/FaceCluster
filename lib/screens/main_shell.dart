import 'package:flutter/material.dart';

import '../services/inference/backend_registry.dart';
import '../services/inference/tflite/tflite_face_detector.dart';
import '../services/inference/tflite/tflite_face_embedder.dart';
import '../services/inference/ncnn/ncnn_bindings.dart';
import '../services/inference/ncnn/ncnn_face_detector.dart';
import '../services/inference/ncnn/ncnn_face_embedder.dart';
import 'home_screen.dart';
import 'benchmark_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  late final BackendRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = BackendRegistry();
    // Register NCNN first so it's the default when available
    if (NcnnBindings.instance.isAvailable) {
      _registry.register(
        'NCNN',
        detector: () => NcnnFaceDetector(),
        embedder: () => NcnnFaceEmbedder(),
      );
    }
    _registry.register(
      'TFLite',
      detector: () => TFLiteFaceDetector(),
      embedder: () => TFLiteFaceEmbedder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          ClusterTab(registry: _registry),
          BenchmarkScreen(registry: _registry),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.face),
            label: 'Cluster',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Benchmark',
          ),
        ],
      ),
    );
  }
}
