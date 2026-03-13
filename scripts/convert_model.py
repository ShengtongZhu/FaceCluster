#!/usr/bin/env python3
"""
Convert InsightFace official w600k_mbf (MobileFaceNet) model from ONNX to TFLite.

Model provenance:
  - Source: InsightFace official model zoo (deepinsight/insightface)
  - Model: w600k_mbf (MobileFaceNet backbone, trained on WebFace600K)
  - Package: buffalo_sc (smallest official bundle, ~16MB)
  - License: Non-commercial research only
  - LFW accuracy: 99.70%
  - Input: [1, 3, 112, 112] (NCHW, BGR, normalized to [-1, 1])
  - Output: [1, 512] (float32, L2-normalized embedding)

Conversion pipeline:
  ONNX → TFLite (via onnx2tf, which handles NCHW→NHWC transpose)

Usage:
  pip install insightface onnxruntime onnx onnx2tf tensorflow
  python scripts/convert_model.py

Output:
  assets/models/MobileFaceNet.tflite
"""

import os
import sys
import glob
import shutil


def main():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_path = os.path.join(project_root, "assets", "models", "MobileFaceNet.tflite")

    print("=" * 60)
    print("InsightFace w600k_mbf → TFLite Converter")
    print("=" * 60)

    # Step 1: Download and extract the ONNX model
    print("\n[1/3] Downloading InsightFace buffalo_sc model pack...")
    onnx_path = download_and_extract_model()

    # Step 2: Convert ONNX to TFLite via onnx2tf
    print("\n[2/3] Converting ONNX → TFLite (via onnx2tf)...")
    convert_onnx_to_tflite(onnx_path, output_path)

    # Step 3: Validate the output
    print("\n[3/3] Validating converted model...")
    validate_model(output_path)

    print(f"\n✅ Model saved to: {output_path}")
    print(f"   File size: {os.path.getsize(output_path) / 1024 / 1024:.1f} MB")


def download_and_extract_model():
    """Download buffalo_sc and extract w600k_mbf.onnx."""
    try:
        from insightface.app import FaceAnalysis

        # This triggers automatic download of the model pack
        app = FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
        app.prepare(ctx_id=-1)

        model_dir = os.path.join(
            os.path.expanduser("~"), ".insightface", "models", "buffalo_sc"
        )

        # List all ONNX files found
        for f in os.listdir(model_dir):
            if f.endswith(".onnx"):
                print(f"  Found: {f}")

        # The recognition model in buffalo_sc
        onnx_path = os.path.join(model_dir, "w600k_mbf.onnx")
        if not os.path.exists(onnx_path):
            for f in os.listdir(model_dir):
                if "mbf" in f.lower() or "w600k" in f.lower():
                    onnx_path = os.path.join(model_dir, f)
                    break

        if not os.path.exists(onnx_path):
            print(f"  Available files in {model_dir}:")
            for f in os.listdir(model_dir):
                print(f"    - {f}")
            raise FileNotFoundError(
                "Could not find w600k_mbf.onnx in buffalo_sc package."
            )

        print(f"  Model found: {onnx_path}")
        return onnx_path

    except ImportError:
        print("ERROR: 'insightface' package not installed.")
        print("Run: pip install insightface onnxruntime")
        sys.exit(1)


def convert_onnx_to_tflite(onnx_path, output_path):
    """Convert ONNX model to TFLite using onnx2tf."""
    import onnx

    # Print ONNX model info
    onnx_model = onnx.load(onnx_path)
    input_shape = onnx_model.graph.input[0].type.tensor_type.shape
    dims = [d.dim_value for d in input_shape.dim]
    print(f"  ONNX input shape: {dims}")

    output_shape = onnx_model.graph.output[0].type.tensor_type.shape
    out_dims = [d.dim_value for d in output_shape.dim]
    print(f"  ONNX output shape: {out_dims}")

    # onnx2tf converts ONNX → TF SavedModel → TFLite in one step
    # It handles NCHW→NHWC transpose automatically
    import onnx2tf

    out_dir = "onnx2tf_output"
    # First, fix the dynamic batch dimension to 1
    import onnx
    from onnx import shape_inference
    import numpy as np

    model = onnx.load(onnx_path)
    # Set batch dim to 1
    for inp in model.graph.input:
        inp.type.tensor_type.shape.dim[0].dim_value = 1
    for out in model.graph.output:
        out.type.tensor_type.shape.dim[0].dim_value = 1

    fixed_onnx = os.path.join(out_dir, "w600k_mbf_fixed.onnx")
    os.makedirs(out_dir, exist_ok=True)
    onnx.save(model, fixed_onnx)

    # Convert with NCHW input kept as-is to avoid transpose issues
    # with depthwise convolutions in MobileFaceNet
    onnx2tf.convert(
        input_onnx_file_path=fixed_onnx,
        output_folder_path=out_dir,
        keep_ncw_or_nchw_or_ncdhw_input_names=[model.graph.input[0].name],
        non_verbose=True,
    )

    # Find the generated .tflite file
    tflite_files = glob.glob(os.path.join(out_dir, "*.tflite"))
    if not tflite_files:
        # onnx2tf may put it in a subdirectory
        tflite_files = glob.glob(os.path.join(out_dir, "**", "*.tflite"), recursive=True)

    if not tflite_files:
        raise FileNotFoundError(
            f"No .tflite file found in {out_dir}. "
            f"Contents: {os.listdir(out_dir)}"
        )

    # Use the first (and typically only) tflite file
    src_tflite = tflite_files[0]
    print(f"  Generated: {src_tflite}")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    shutil.copy2(src_tflite, output_path)

    # Clean up
    shutil.rmtree(out_dir, ignore_errors=True)


def validate_model(tflite_path):
    """Validate the converted TFLite model's input/output shapes."""
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter

    interpreter = Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"  Input shape:  {input_details[0]['shape']}  dtype: {input_details[0]['dtype']}")
    print(f"  Output shape: {output_details[0]['shape']}  dtype: {output_details[0]['dtype']}")

    input_shape = list(input_details[0]['shape'])
    output_shape = list(output_details[0]['shape'])

    # Input should be [1, 112, 112, 3] (NHWC) or [1, 3, 112, 112] (NCHW)
    if input_shape in [[1, 112, 112, 3], [1, 3, 112, 112]]:
        layout = "NHWC" if input_shape == [1, 112, 112, 3] else "NCHW"
        print(f"  ✅ Input shape valid ({layout})")
    else:
        print(f"  ⚠️  Unexpected input shape: {input_shape}")

    # Output should be [1, 512]
    if output_shape == [1, 512]:
        print(f"  ✅ Output shape valid (512-dim embedding)")
    else:
        print(f"  ⚠️  Unexpected output shape: {output_shape}")


if __name__ == "__main__":
    main()
