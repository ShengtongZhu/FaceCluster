#!/usr/bin/env python3
"""
End-to-end test of the face alignment + embedding pipeline.
Compares our TFLite pipeline with InsightFace reference pipeline.

Tests:
1. Alignment quality (visual + numeric)
2. Embedding quality (cosine similarity same/diff person)
3. BGR vs RGB verification
4. Reference ONNX vs our TFLite comparison
"""

import os
import sys
import urllib.request
import numpy as np
import cv2

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
TFLITE_MODEL = os.path.join(PROJECT_DIR, "assets", "models", "MobileFaceNet.tflite")
ONNX_MODEL = os.path.expanduser("~/.insightface/models/buffalo_sc/w600k_mbf.onnx")
TEST_DIR = os.path.join(SCRIPT_DIR, "test_faces")

# InsightFace arcface template for 112x112
TEMPLATE = np.array([
    [38.2946, 51.6963],  # left eye
    [73.5318, 51.5014],  # right eye
    [56.0252, 71.7366],  # nose
    [41.5493, 92.3655],  # left mouth
    [70.7299, 92.2041],  # right mouth
], dtype=np.float32)


def download_test_images():
    """Download LFW test face images."""
    os.makedirs(TEST_DIR, exist_ok=True)

    # Use known public domain face images from LFW (via direct URLs)
    urls = {
        # Same person (George W Bush) - multiple images
        "bush_1.jpg": "http://vis-www.cs.umass.edu/lfw/images/George_W_Bush/George_W_Bush_0001.jpg",
        "bush_2.jpg": "http://vis-www.cs.umass.edu/lfw/images/George_W_Bush/George_W_Bush_0002.jpg",
        "bush_3.jpg": "http://vis-www.cs.umass.edu/lfw/images/George_W_Bush/George_W_Bush_0003.jpg",
        # Different person (Colin Powell)
        "powell_1.jpg": "http://vis-www.cs.umass.edu/lfw/images/Colin_Powell/Colin_Powell_0001.jpg",
        "powell_2.jpg": "http://vis-www.cs.umass.edu/lfw/images/Colin_Powell/Colin_Powell_0002.jpg",
        # Different person (Tony Blair)
        "blair_1.jpg": "http://vis-www.cs.umass.edu/lfw/images/Tony_Blair/Tony_Blair_0001.jpg",
    }

    for name, url in urls.items():
        path = os.path.join(TEST_DIR, name)
        if not os.path.exists(path):
            print(f"  Downloading {name}...")
            try:
                urllib.request.urlretrieve(url, path)
            except Exception as e:
                print(f"  Failed to download {name}: {e}")
                continue
    return TEST_DIR


def detect_landmarks_insightface(img_path):
    """Detect face landmarks using InsightFace (reference)."""
    from insightface.app import FaceAnalysis
    app = FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
    app.prepare(ctx_id=-1)

    img = cv2.imread(img_path)
    faces = app.get(img)
    if not faces:
        return None, None
    # Return the first face's 5 landmarks and the face object
    return faces[0].kps, faces[0]


def align_insightface_reference(img_path):
    """Align face using InsightFace's own alignment (reference)."""
    from insightface.utils.face_align import norm_crop
    img = cv2.imread(img_path)
    kps, face = detect_landmarks_insightface(img_path)
    if kps is None:
        return None
    aligned = norm_crop(img, kps, image_size=112)
    return aligned


def align_our_method(img_bgr, landmarks_5pt):
    """
    Replicate our Dart alignment logic in Python.
    Uses 3 points (left eye, right eye, nose) for affine transform.
    """
    src_pts = landmarks_5pt[:3].astype(np.float64)  # left eye, right eye, nose
    dst_pts = TEMPLATE[:3].astype(np.float64)

    # Solve affine: same as Dart _solveAffineMatrix
    # We need inverse mapping: dst -> src
    M_inv = solve_affine_3pt(dst_pts, src_pts)

    result = np.zeros((112, 112, 3), dtype=np.uint8)
    for y in range(112):
        for x in range(112):
            sx = M_inv[0] * x + M_inv[1] * y + M_inv[2]
            sy = M_inv[3] * x + M_inv[4] * y + M_inv[5]
            result[y, x] = bilinear_sample(img_bgr, sx, sy)

    return result


def align_opencv_reference(img_bgr, landmarks_5pt):
    """Align using OpenCV's estimateAffinePartial2D (proper reference)."""
    src = landmarks_5pt[:3].astype(np.float32)
    dst = TEMPLATE[:3].astype(np.float32)
    M = cv2.getAffineTransform(src, dst)
    aligned = cv2.warpAffine(img_bgr, M, (112, 112))
    return aligned


def solve_affine_3pt(from_pts, to_pts):
    """Exact replication of Dart _solveAffineMatrix."""
    x0, y0 = from_pts[0]
    x1, y1 = from_pts[1]
    x2, y2 = from_pts[2]
    u0, v0 = to_pts[0]
    u1, v1 = to_pts[1]
    u2, v2 = to_pts[2]

    det = x0 * (y1 - y2) - y0 * (x1 - x2) + (x1 * y2 - x2 * y1)
    if abs(det) < 1e-10:
        return [1, 0, 0, 0, 1, 0]

    inv_det = 1.0 / det
    i00 = (y1 - y2) * inv_det
    i01 = (y2 - y0) * inv_det
    i02 = (y0 - y1) * inv_det
    i10 = (x2 - x1) * inv_det
    i11 = (x0 - x2) * inv_det
    i12 = (x1 - x0) * inv_det
    i20 = (x1 * y2 - x2 * y1) * inv_det
    i21 = (x2 * y0 - x0 * y2) * inv_det
    i22 = (x0 * y1 - x1 * y0) * inv_det

    a = u0 * i00 + u1 * i01 + u2 * i02
    b = u0 * i10 + u1 * i11 + u2 * i12
    tx = u0 * i20 + u1 * i21 + u2 * i22
    c = v0 * i00 + v1 * i01 + v2 * i02
    d = v0 * i10 + v1 * i11 + v2 * i12
    ty = v0 * i20 + v1 * i21 + v2 * i22

    return [a, b, tx, c, d, ty]


def bilinear_sample(img, x, y):
    h, w = img.shape[:2]
    x0 = int(np.floor(x))
    y0 = int(np.floor(y))
    x1 = x0 + 1
    y1 = y0 + 1

    if x0 < 0 or y0 < 0 or x1 >= w or y1 >= h:
        return np.array([0, 0, 0], dtype=np.uint8)

    fx = x - x0
    fy = y - y0

    p00 = img[y0, x0].astype(np.float64)
    p10 = img[y0, x1].astype(np.float64)
    p01 = img[y1, x0].astype(np.float64)
    p11 = img[y1, x1].astype(np.float64)

    top = p00 * (1 - fx) + p10 * fx
    bot = p01 * (1 - fx) + p11 * fx
    val = top * (1 - fy) + bot * fy

    return np.clip(val, 0, 255).astype(np.uint8)


def preprocess_bgr(aligned_bgr):
    """Preprocess for TFLite: BGR, normalized to [-1, 1], NHWC."""
    img = aligned_bgr.astype(np.float32)
    img = (img - 127.5) / 128.0
    return img[np.newaxis]  # [1, 112, 112, 3]


def preprocess_rgb(aligned_bgr):
    """Preprocess as RGB, normalized to [-1, 1], NHWC."""
    img = cv2.cvtColor(aligned_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    img = (img - 127.5) / 128.0
    return img[np.newaxis]


def run_tflite(input_nhwc):
    """Run TFLite model."""
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter

    interp = Interpreter(model_path=TFLITE_MODEL)
    interp.allocate_tensors()
    inp_idx = interp.get_input_details()[0]['index']
    out_idx = interp.get_output_details()[0]['index']

    interp.set_tensor(inp_idx, input_nhwc.astype(np.float32))
    interp.invoke()
    emb = interp.get_tensor(out_idx)[0].copy()
    return emb / np.linalg.norm(emb)


def run_onnx(aligned_bgr):
    """Run ONNX model (reference). Expects BGR, NCHW."""
    import onnxruntime as ort
    sess = ort.InferenceSession(ONNX_MODEL, providers=["CPUExecutionProvider"])
    img = aligned_bgr.astype(np.float32)
    img = (img - 127.5) / 128.0
    img = np.transpose(img, (2, 0, 1))[np.newaxis]  # NCHW
    out = sess.run(None, {sess.get_inputs()[0].name: img})[0][0]
    return out / np.linalg.norm(out)


def cosine_sim(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def main():
    print("=" * 70)
    print("Face Alignment & Embedding Pipeline Test")
    print("=" * 70)

    # Step 1: Download test images
    print("\n[1/5] Downloading test images...")
    download_test_images()

    test_files = sorted([f for f in os.listdir(TEST_DIR) if f.endswith(".jpg")])
    if len(test_files) < 2:
        print("ERROR: Not enough test images downloaded.")
        sys.exit(1)
    print(f"  Found {len(test_files)} test images")

    # Step 2: Detect landmarks using InsightFace (reference)
    print("\n[2/5] Detecting landmarks with InsightFace...")
    from insightface.app import FaceAnalysis
    app = FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
    app.prepare(ctx_id=-1)

    face_data = {}
    for fname in test_files:
        path = os.path.join(TEST_DIR, fname)
        img = cv2.imread(path)
        if img is None:
            continue
        faces = app.get(img)
        if faces:
            face_data[fname] = {
                "img": img,
                "kps": faces[0].kps,
                "face": faces[0],
            }
            print(f"  {fname}: detected, landmarks shape={faces[0].kps.shape}")
        else:
            print(f"  {fname}: NO FACE DETECTED")

    if len(face_data) < 2:
        print("ERROR: Not enough faces detected.")
        sys.exit(1)

    # Step 3: Compare alignment methods
    print("\n[3/5] Comparing alignment methods...")
    from insightface.utils.face_align import norm_crop

    alignments = {}
    for fname, data in face_data.items():
        # Reference: InsightFace alignment
        ref_aligned = norm_crop(data["img"], data["kps"], image_size=112)

        # Our method: 3-point affine (replicating Dart code)
        our_aligned = align_our_method(data["img"], data["kps"])

        # OpenCV reference: 3-point affine (using cv2)
        cv_aligned = align_opencv_reference(data["img"], data["kps"])

        alignments[fname] = {
            "reference": ref_aligned,
            "ours": our_aligned,
            "opencv": cv_aligned,
        }

        # Save aligned images for visual inspection
        out_dir = os.path.join(TEST_DIR, "aligned")
        os.makedirs(out_dir, exist_ok=True)
        base = fname.replace(".jpg", "")
        cv2.imwrite(os.path.join(out_dir, f"{base}_ref.jpg"), ref_aligned)
        cv2.imwrite(os.path.join(out_dir, f"{base}_ours.jpg"), our_aligned)
        cv2.imwrite(os.path.join(out_dir, f"{base}_cv.jpg"), cv_aligned)

    print(f"  Saved aligned images to {os.path.join(TEST_DIR, 'aligned')}")

    # Step 4: Compare embeddings
    print("\n[4/5] Computing embeddings...")
    print()

    embeddings = {}
    for fname, aligns in alignments.items():
        ref = aligns["reference"]
        ours = aligns["ours"]

        # ONNX reference (InsightFace alignment + ONNX model)
        emb_onnx_ref = run_onnx(ref)

        # TFLite + InsightFace alignment + BGR
        emb_tfl_ref_bgr = run_tflite(preprocess_bgr(ref))

        # TFLite + our alignment + BGR
        emb_tfl_ours_bgr = run_tflite(preprocess_bgr(ours))

        # TFLite + our alignment + RGB
        emb_tfl_ours_rgb = run_tflite(preprocess_rgb(ours))

        # TFLite + OpenCV alignment + BGR
        cv_aligned = aligns["opencv"]
        emb_tfl_cv_bgr = run_tflite(preprocess_bgr(cv_aligned))

        embeddings[fname] = {
            "onnx_ref": emb_onnx_ref,
            "tfl_ref_bgr": emb_tfl_ref_bgr,
            "tfl_ours_bgr": emb_tfl_ours_bgr,
            "tfl_ours_rgb": emb_tfl_ours_rgb,
            "tfl_cv_bgr": emb_tfl_cv_bgr,
        }

        # Print per-image alignment quality
        sim_ref = cosine_sim(emb_onnx_ref, emb_tfl_ref_bgr)
        sim_ours = cosine_sim(emb_onnx_ref, emb_tfl_ours_bgr)
        sim_cv = cosine_sim(emb_onnx_ref, emb_tfl_cv_bgr)
        sim_rgb = cosine_sim(emb_onnx_ref, emb_tfl_ours_rgb)
        print(f"  {fname}:")
        print(f"    ONNX vs TFLite(ref align, BGR):  {sim_ref:.4f}")
        print(f"    ONNX vs TFLite(our align, BGR):  {sim_ours:.4f}")
        print(f"    ONNX vs TFLite(cv2 align, BGR):  {sim_cv:.4f}")
        print(f"    ONNX vs TFLite(our align, RGB):  {sim_rgb:.4f}")

    # Step 5: Pairwise similarity test
    print("\n[5/5] Pairwise similarity (TFLite + our alignment + BGR):")
    print()

    fnames = list(embeddings.keys())
    print(f"  {'':>15}", end="")
    for fn in fnames:
        print(f"  {fn[:10]:>10}", end="")
    print()

    for i, fn_i in enumerate(fnames):
        print(f"  {fn_i[:15]:>15}", end="")
        for j, fn_j in enumerate(fnames):
            sim = cosine_sim(
                embeddings[fn_i]["tfl_ours_bgr"],
                embeddings[fn_j]["tfl_ours_bgr"]
            )
            print(f"  {sim:>10.4f}", end="")
        print()

    # Also print reference pipeline pairwise
    print()
    print("  Pairwise similarity (ONNX + ref alignment) [ground truth]:")
    print(f"  {'':>15}", end="")
    for fn in fnames:
        print(f"  {fn[:10]:>10}", end="")
    print()

    for i, fn_i in enumerate(fnames):
        print(f"  {fn_i[:15]:>15}", end="")
        for j, fn_j in enumerate(fnames):
            sim = cosine_sim(
                embeddings[fn_i]["onnx_ref"],
                embeddings[fn_j]["onnx_ref"]
            )
            print(f"  {sim:>10.4f}", end="")
        print()

    print("\n" + "=" * 70)
    print("DONE. Check scripts/test_faces/aligned/ for visual comparison.")
    print("=" * 70)


if __name__ == "__main__":
    main()
