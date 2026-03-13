## ADDED Requirements

### Requirement: MobileFaceNet embedding generation
The system SHALL use MobileFaceNet (TFLite format, ~2MB) to generate a 512-dimensional float32 embedding vector for each aligned face image.

#### Scenario: Embedding generated for aligned face
- **WHEN** an aligned 112x112 face image is provided to the model
- **THEN** a 512-dimensional float32 vector is produced and returned

### Requirement: Embedding persistence
The system SHALL store each face's embedding vector as a BLOB (2048 bytes) in the faces table of the local SQLite database.

#### Scenario: Embedding saved to database
- **WHEN** an embedding vector is generated for a face
- **THEN** the 512 x float32 embedding is stored as a BLOB in the faces table linked to the corresponding photo
