## ADDED Requirements

### Requirement: Model conversion script
The project SHALL include a Python script at `scripts/convert_model.py` that converts InsightFace's official w600k_mbf ONNX model to TFLite format.

#### Scenario: Successful model conversion
- **WHEN** the developer runs `python scripts/convert_model.py`
- **THEN** the script downloads the InsightFace buffalo_sc model pack, extracts w600k_mbf.onnx, converts it to TFLite format, and saves the result to `assets/models/MobileFaceNet.tflite`

#### Scenario: Output model validation
- **WHEN** the conversion completes
- **THEN** the script prints the model's input shape (expected: [1, 112, 112, 3]) and output shape (expected: [1, 512]) for verification

### Requirement: Reproducible model provenance
The conversion script SHALL document the exact model source, version, and conversion steps so any developer can reproduce the same TFLite model.

#### Scenario: Script includes provenance metadata
- **WHEN** a developer reads the conversion script
- **THEN** it contains the InsightFace model URL, model name (w600k_mbf), and the conversion pipeline used (onnx → tflite via onnx2tf)
