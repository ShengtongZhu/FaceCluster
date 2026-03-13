## ADDED Requirements

### Requirement: DBSCAN clustering with cosine similarity
The system SHALL implement DBSCAN clustering algorithm in pure Dart using cosine similarity as the distance function.

#### Scenario: Faces clustered into person groups
- **WHEN** clustering is triggered on all stored face embeddings
- **THEN** faces are grouped into N person clusters plus 1 unclustered group (cluster_id = -1)

### Requirement: Adjustable clustering parameters
The system SHALL provide two adjustable parameters via UI sliders:
- Similarity threshold: default 0.6, range 0.4-0.8
- Minimum samples (min_samples): default 2

#### Scenario: User adjusts similarity threshold
- **WHEN** user moves the similarity threshold slider to 0.7
- **THEN** re-clustering uses 0.7 as the cosine similarity threshold

#### Scenario: User adjusts min_samples
- **WHEN** user sets min_samples to 3
- **THEN** re-clustering requires at least 3 faces to form a cluster

### Requirement: Clustering result persistence
The system SHALL store the cluster_id for each face in the faces table, with -1 indicating unclustered.

#### Scenario: Cluster assignments saved
- **WHEN** clustering completes
- **THEN** each face record in the database is updated with its assigned cluster_id
