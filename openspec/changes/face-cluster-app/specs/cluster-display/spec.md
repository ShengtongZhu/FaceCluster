## ADDED Requirements

### Requirement: Person group list view
The system SHALL display a list of person groups, each showing a representative face thumbnail and the count of photos containing that person.

#### Scenario: User views cluster results
- **WHEN** clustering is complete and user navigates to results
- **THEN** a list of person groups is displayed with one representative face and photo count per group

### Requirement: Person group detail view
The system SHALL display all photo thumbnails belonging to a selected person group.

#### Scenario: User taps a person group
- **WHEN** user taps on a person group in the list
- **THEN** all photos containing that person are displayed as thumbnails

### Requirement: Unclustered group display
The system SHALL display an unclustered group separately, containing all faces that were not assigned to any cluster.

#### Scenario: User views unclustered faces
- **WHEN** there are faces with cluster_id = -1
- **THEN** they are shown in a separate "unclustered" section
