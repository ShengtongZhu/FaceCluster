## ADDED Requirements

### Requirement: Face detection using ML Kit
The system SHALL use Google ML Kit (google_mlkit_face_detection) to detect faces in each imported photo.

#### Scenario: Photo with faces detected
- **WHEN** a photo containing one or more human faces is processed
- **THEN** the system detects all faces and returns bounding box coordinates for each

#### Scenario: Photo with no faces
- **WHEN** a photo containing no human faces is processed
- **THEN** the system returns zero detections and moves to the next photo

### Requirement: Face cropping and alignment
The system SHALL crop each detected face and apply affine alignment to produce a 112x112 pixel image.

#### Scenario: Face aligned to standard size
- **WHEN** a face is detected with bounding box and landmarks
- **THEN** the face is cropped and affine-aligned to 112x112 pixels

### Requirement: Face count display
The system SHALL display the total number of detected faces during processing.

#### Scenario: Detection progress shown
- **WHEN** face detection is in progress
- **THEN** the UI displays the current count of detected faces

### Requirement: Bounding box visualization
The system SHALL display bounding boxes around detected faces on each photo for browsing.

#### Scenario: User browses detected faces
- **WHEN** user views a processed photo
- **THEN** each detected face is highlighted with a bounding box overlay
