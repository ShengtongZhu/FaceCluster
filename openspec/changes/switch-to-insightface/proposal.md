## Why

当前使用的 MobileFaceNet 模型来自第三方 GitHub repo（syaringan357），来源不可追溯，输出维度不确定，精度无法验证。参考 Immich（开源 Google Photos 替代品，40k+ stars）的做法，切换到 InsightFace 官方 MobileFaceNet (MBF@WebFace600K) 模型，获得可靠的来源、已验证的 512 维输出和 99.70% LFW 精度。

## What Changes

- **BREAKING** 替换 embedding 模型：从非官方 MobileFaceNet.tflite 切换到 InsightFace 官方 w600k_mbf 模型
- 新增模型转换流程：ONNX → TFLite 的转换脚本
- 调整 EmbeddingService 以适配新模型的输入预处理要求
- 已有的 embedding 数据需要全量重新生成（模型变更后向量不兼容）

## Capabilities

### New Capabilities

- `model-conversion`: InsightFace ONNX 模型到 TFLite 格式的转换流程与脚本

### Modified Capabilities

- `face-embedding`: 切换到 InsightFace 官方 w600k_mbf 模型，确保 512 维输出，调整输入预处理

## Impact

- **模型文件**: `assets/models/MobileFaceNet.tflite` 将被替换为转换后的 InsightFace 模型
- **代码**: `lib/services/embedding_service.dart` 需要调整预处理逻辑（归一化参数可能不同）
- **数据**: 切换模型后，已有的 face embedding 数据不兼容，需全量重算
- **依赖**: 新增 Python 依赖用于一次性模型转换（insightface, onnxruntime, onnx, onnx2tf, tensorflow）
- **大小**: 模型文件从 ~5MB 变为 ~6.5MB
