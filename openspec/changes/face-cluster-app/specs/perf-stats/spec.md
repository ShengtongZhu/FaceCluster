## ADDED Requirements

### Requirement: Per-stage timing
The system SHALL measure and display elapsed time for each processing stage: face detection, embedding generation, and clustering.

#### Scenario: Timing displayed after processing
- **WHEN** all processing stages complete
- **THEN** the UI shows elapsed time in milliseconds for detection, embedding, and clustering separately

### Requirement: Average per-photo processing time
The system SHALL calculate and display the average processing time per photo.

#### Scenario: Average time shown
- **WHEN** processing completes for N photos
- **THEN** total processing time divided by N is displayed

### Requirement: Face and cluster count display
The system SHALL display the total number of detected faces and the number of person clusters.

#### Scenario: Counts shown after processing
- **WHEN** processing and clustering complete
- **THEN** the UI shows total face count and number of person groups

### Requirement: Peak memory usage display
The system SHALL measure and display peak memory usage during processing.

#### Scenario: Memory usage shown
- **WHEN** processing completes
- **THEN** the UI displays the peak memory consumption in MB
