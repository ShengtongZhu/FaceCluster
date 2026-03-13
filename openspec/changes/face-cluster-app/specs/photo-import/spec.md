## ADDED Requirements

### Requirement: Batch photo selection from device gallery
The system SHALL allow users to select multiple photos from the device photo gallery in a single operation.

#### Scenario: User selects multiple photos
- **WHEN** user taps the import button and selects multiple photos from the gallery
- **THEN** all selected photos are imported into the app and stored in the local database

#### Scenario: User selects a folder/album
- **WHEN** user selects an entire album or folder
- **THEN** all photos in that album/folder are imported in one operation

### Requirement: Imported photo persistence
The system SHALL persist imported photo metadata (path, width, height, created_at) in the local SQLite database.

#### Scenario: Photo metadata stored after import
- **WHEN** photos are successfully imported
- **THEN** each photo's local path, dimensions, and creation time are saved to the photos table
