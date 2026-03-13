# FaceCluster

基于 Flutter 的人脸聚类应用，使用 InsightFace 官方 w600k_mbf 模型生成 512 维人脸 embedding，实现自动人脸分组。

## 构建与部署

### 前置条件

- Flutter SDK
- Android SDK（API 31+）
- 连接 Android 设备并开启 USB 调试

### 构建 Release APK

```bash
flutter build apk
```

### 安装到手机

```bash
# 查看已连接设备
flutter devices

# 安装到指定设备（替换为你的设备 ID）
flutter install -d <device_id>
```

安装时需要在手机上确认安装弹窗。

## 模型转换

项目使用 InsightFace 官方 w600k_mbf 模型（buffalo_sc 包），需要从 ONNX 转换为 TFLite 格式。

### 前置条件

- Python 3.12（TensorFlow 不支持 3.13+）

```bash
# macOS 安装 Python 3.12
brew install python@3.12
```

### 运行转换

```bash
# 创建虚拟环境
/opt/homebrew/bin/python3.12 -m venv scripts/.venv
source scripts/.venv/bin/activate

# 安装依赖
pip install insightface onnxruntime onnx onnx2tf tensorflow

# 运行转换脚本
python scripts/convert_model.py
```

脚本会自动下载 InsightFace buffalo_sc 模型包，提取 w600k_mbf.onnx，转换为 TFLite 并保存到 `assets/models/MobileFaceNet.tflite`。

转换后模型：
- 输入：`[1, 112, 112, 3]`（NHWC, BGR, float32）
- 输出：`[1, 512]`（float32）
- 大小：~6.5MB
