## 1. Project Setup

- [x] 1.1 Initialize Flutter project with iOS and Android targets
- [x] 1.2 Add dependencies: google_mlkit_face_detection, tflite_flutter, drift, image, photo_manager
- [x] 1.3 Configure iOS/Android permissions for photo library access
- [x] 1.4 Add MobileFaceNet.tflite model file to assets

## 2. Local Storage (drift)

- [x] 2.1 Define photos table schema with drift (id, path, width, height, created_at)
- [x] 2.2 Define faces table schema with drift (id, photo_id, bbox_x/y/w/h, embedding, cluster_id)
- [x] 2.3 Run drift code generation and verify database creation
- [x] 2.4 Implement CRUD operations for photos and faces tables

## 3. Photo Import

- [x] 3.1 Implement photo picker UI with batch selection support (photo_manager)
- [x] 3.2 Save imported photo metadata to photos table
- [x] 3.3 Display imported photos count and preview

## 4. Face Detection

- [x] 4.1 Implement ML Kit face detection service (process single photo, return face bounding boxes)
- [x] 4.2 Implement face cropping and affine alignment to 112x112 using image package
- [x] 4.3 Save detected face records (photo_id, normalized bbox) to faces table
- [x] 4.4 Implement bounding box visualization overlay on photos
- [x] 4.5 Add detection progress UI showing face count

## 5. Face Embedding

- [x] 5.1 Load MobileFaceNet.tflite model with tflite_flutter
- [x] 5.2 Implement embedding inference: 112x112 image → 512-dim float32 vector
- [x] 5.3 Store embedding as BLOB in faces table
- [x] 5.4 Add embedding progress UI

## 6. Face Clustering

- [x] 6.1 Implement cosine similarity function for 512-dim vectors
- [x] 6.2 Implement DBSCAN algorithm in pure Dart
- [x] 6.3 Add UI sliders for similarity threshold (0.4-0.8, default 0.6) and min_samples (default 2)
- [x] 6.4 Update faces table cluster_id with clustering results
- [x] 6.5 Support re-clustering when parameters change

## 7. Cluster Results Display

- [x] 7.1 Build person group list page (representative face thumbnail + photo count per group)
- [x] 7.2 Build person group detail page (all photo thumbnails for selected person)
- [x] 7.3 Build unclustered group display section

## 8. Performance Statistics

- [x] 8.1 Instrument timing for detection, embedding, and clustering stages
- [x] 8.2 Calculate and display average per-photo processing time
- [x] 8.3 Display total face count and person group count
- [x] 8.4 Measure and display peak memory usage
- [x] 8.5 Build performance statistics summary UI

## 9. Integration & Polish

- [x] 9.1 Wire up end-to-end flow: import → detect → embed → cluster → display
- [x] 9.2 Add processing progress indicators and error handling
- [x] 9.3 Implement batch processing with memory management (prevent OOM)
- [ ] 9.4 Test on iOS and Android devices
