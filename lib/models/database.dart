import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
}

class Faces extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get photoId => integer().references(Photos, #id)();
  RealColumn get bboxX => real()();
  RealColumn get bboxY => real()();
  RealColumn get bboxW => real()();
  RealColumn get bboxH => real()();
  BlobColumn get embedding => blob().nullable()();
  IntColumn get clusterId => integer().withDefault(const Constant(-1))();
}

@DriftDatabase(tables: [Photos, Faces])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  @override
  int get schemaVersion => 1;

  // Photos CRUD
  Future<List<Photo>> getAllPhotos() => select(photos).get();

  Future<int> insertPhoto(PhotosCompanion entry) =>
      into(photos).insert(entry);

  Future<void> deleteAllPhotos() async {
    await delete(faces).go();
    await delete(photos).go();
  }

  // Faces CRUD
  Future<List<Face>> getAllFaces() => select(faces).get();

  Future<List<Face>> getFacesForPhoto(int photoId) =>
      (select(faces)..where((f) => f.photoId.equals(photoId))).get();

  Future<int> insertFace(FacesCompanion entry) =>
      into(faces).insert(entry);

  Future<void> updateFaceEmbedding(int faceId, Uint8List embeddingData) =>
      (update(faces)..where((f) => f.id.equals(faceId)))
          .write(FacesCompanion(embedding: Value(embeddingData)));

  Future<void> updateFaceClusterId(int faceId, int clusterId) =>
      (update(faces)..where((f) => f.id.equals(faceId)))
          .write(FacesCompanion(clusterId: Value(clusterId)));

  Future<void> resetAllClusterIds() =>
      (update(faces)).write(const FacesCompanion(clusterId: Value(-1)));

  Future<List<Face>> getFacesByCluster(int clusterId) =>
      (select(faces)..where((f) => f.clusterId.equals(clusterId))).get();

  Future<List<int>> getDistinctClusterIds() async {
    final query = selectOnly(faces, distinct: true)
      ..addColumns([faces.clusterId]);
    final rows = await query.get();
    return rows.map((row) => row.read(faces.clusterId)!).toList()..sort();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'face_cluster.db'));
    return NativeDatabase.createInBackground(file);
  });
}
