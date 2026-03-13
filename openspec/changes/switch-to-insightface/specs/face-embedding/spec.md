## MODIFIED Requirements

### Requirement: MobileFaceNet embedding generation
The system SHALL use InsightFace official w600k_mbf model (converted to TFLite format) to generate a 512-dimensional float32 embedding vector for each aligned face image. Input preprocessing MUST use BGR channel order and normalize pixel values to [-1, 1] range using (pixel - 127.5) / 128.0.

#### Scenario: Embedding generated for aligned face
- **WHEN** an aligned 112x112 face image is provided to the model
- **THEN** a 512-dimensional float32 vector is produced with L2-normalized values

#### Scenario: Input channel order is BGR
- **WHEN** a face image is preprocessed for the model
- **THEN** the RGB channels are swapped to BGR order before feeding to the model

#### Scenario: Embedding dimension is exactly 512
- **WHEN** the model is loaded
- **THEN** the output tensor shape confirms 512-dimensional output
