import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Full-screen photo grid with multi-select. Returns selected [AssetEntity] list.
class PhotoSelectionScreen extends StatefulWidget {
  final AssetPathEntity album;

  const PhotoSelectionScreen({super.key, required this.album});

  @override
  State<PhotoSelectionScreen> createState() => _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends State<PhotoSelectionScreen> {
  List<AssetEntity> _assets = [];
  final Set<int> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final count = await widget.album.assetCountAsync;
    final assets =
        await widget.album.getAssetListRange(start: 0, end: count);
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selected.length == _assets.length) {
        _selected.clear();
      } else {
        _selected.addAll(List.generate(_assets.length, (i) => i));
      }
    });
  }

  void _confirm() {
    final selectedAssets =
        _selected.map((i) => _assets[i]).toList(growable: false);
    Navigator.pop(context, selectedAssets);
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _assets.isNotEmpty && _selected.length == _assets.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.name),
        actions: [
          TextButton(
            onPressed: _assets.isEmpty ? null : _toggleSelectAll,
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selected.isEmpty ? null : _confirm,
        icon: const Icon(Icons.check),
        label: Text('Import (${_selected.length})'),
        backgroundColor:
            _selected.isEmpty ? Colors.grey.shade400 : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: _assets.length,
              itemBuilder: (_, i) {
                final asset = _assets[i];
                final isSelected = _selected.contains(i);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(i);
                      } else {
                        _selected.add(i);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: asset.thumbnailDataWithSize(
                          const ThumbnailSize.square(200),
                        ),
                        builder: (_, snap) {
                          if (snap.data == null) {
                            return Container(color: Colors.grey.shade200);
                          }
                          return Image.memory(snap.data!,
                              fit: BoxFit.cover);
                        },
                      ),
                      if (isSelected)
                        Container(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? Colors.blue : Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
