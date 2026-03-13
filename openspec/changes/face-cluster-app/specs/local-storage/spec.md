## ADDED Requirements

### Requirement: Photos table schema
The system SHALL maintain a photos table with columns: id (INTEGER PRIMARY KEY), path (TEXT NOT NULL), width (INTEGER), height (INTEGER), created_at (DATETIME).

#### Scenario: Photo record created
- **WHEN** a photo is imported
- **THEN** a row is inserted into the photos table with the photo's path, dimensions, and creation timestamp

### Requirement: Faces table schema
The system SHALL maintain a faces table with columns: id (INTEGER PRIMARY KEY), photo_id (INTEGER REFERENCES photos), bbox_x (REAL), bbox_y (REAL), bbox_w (REAL), bbox_h (REAL), embedding (BLOB), cluster_id (INTEGER).

#### Scenario: Face record created after detection
- **WHEN** a face is detected in a photo
- **THEN** a row is inserted with photo_id, normalized bounding box coordinates, and null embedding/cluster_id

#### Scenario: Face record updated with embedding
- **WHEN** embedding is generated for a face
- **THEN** the face row's embedding column is updated with the 2048-byte BLOB

#### Scenario: Face record updated with cluster assignment
- **WHEN** clustering completes
- **THEN** the face row's cluster_id is updated with the assigned cluster (-1 for unclustered)

### Requirement: Data managed via drift ORM
The system SHALL use drift (SQLite ORM for Dart) for all database operations with compile-time query verification.

#### Scenario: Database operations use drift
- **WHEN** any database read or write operation is performed
- **THEN** it is executed through drift's type-safe API
