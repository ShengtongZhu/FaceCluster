import 'dart:io';

import 'package:flutter/material.dart';

import '../models/database.dart';

class PersonDetailScreen extends StatelessWidget {
  final String title;
  final List<Face> faces;

  const PersonDetailScreen({
    super.key,
    required this.title,
    required this.faces,
  });

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('$title (${faces.length})'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Photo>>(
        future: db.getAllPhotos(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final photos = snapshot.data!;
          final photoMap = {for (final p in photos) p.id: p};

          // Get unique photos for these faces
          final facePhotos = <int, Photo>{};
          for (final face in faces) {
            final photo = photoMap[face.photoId];
            if (photo != null) {
              facePhotos[photo.id] = photo;
            }
          }

          final uniquePhotos = facePhotos.values.toList();

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: uniquePhotos.length,
            itemBuilder: (ctx, i) {
              final photo = uniquePhotos[i];
              return GestureDetector(
                onTap: () => _showFullImage(context, photo),
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFullImage(BuildContext context, Photo photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(photo.path),
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
