## Context

当前项目使用从 syaringan357 GitHub repo 下载的 MobileFaceNet.tflite（~5.2MB），来源不可靠，输出维度未验证。Immich（开源相册，40k+ stars）使用 InsightFace 官方模型（buffalo_l / antelopev2）做人脸聚类，效果经过大量用户验证。

InsightFace 官方提供 ONNX 格式的模型，需要转换为 TFLite 才能在 Flutter 中使用。

## Goals / Non-Goals

**Goals:**
- 使用 InsightFace 官方 w600k_mbf 模型替换当前不可靠的模型
- 确保输出为 512 维 float32 embedding
- 提供可复现的模型转换脚本
- 保持现有 App 架构不变，仅替换模型和适配预处理

**Non-Goals:**
- 不切换推理框架（继续使用 tflite_flutter，不引入 onnxruntime）
- 不升级到 ResNet50 等更大模型（保持移动端友好）
- 不修改聚类算法或 UI

## Decisions

### 1. 模型来源：InsightFace buffalo_sc 包

**选择**: 从 InsightFace 官方下载 buffalo_sc 包，提取 w600k_mbf.onnx
**理由**: buffalo_sc 是最小的官方包（16MB），包含 MobileFaceNet backbone + WebFace600K 训练权重。这与 Immich 使用的同系列模型一致。
**替代方案**: buffalo_l（326MB，含 ResNet50，太大）；antelopev2（407MB，同样过大）；直接用 Immich 的模型（ONNX 格式，仍需转换）。

### 2. 转换路径：ONNX → TFLite（via onnx2tf）

**选择**: 使用 `onnx2tf` 将 ONNX 直接转为 TFLite（内部经过 TF SavedModel 中间格式）
**理由**: `onnx-tf` 与新版 `onnx` 不兼容（`onnx.mapping` 已移除），`onnx2tf` 是活跃维护的替代方案，自动处理 NCHW→NHWC 转换。需要用 `keep_ncw_or_nchw_or_ncdhw_input_names` 参数解决 MobileFaceNet 深度卷积的转换问题。
**替代方案**:
- `onnx-tf`（已过时，与 onnx >= 1.15 不兼容）
- 在 Flutter 中使用 onnxruntime_flutter（避免转换，但引入新依赖，增加包大小）

### 3. 输入预处理适配

**选择**: 根据 InsightFace 官方规范调整预处理——输入为 112×112 RGB，像素值归一化到 [-1, 1]（即 (pixel - 127.5) / 128.0）
**理由**: 与 InsightFace 训练时的预处理一致，错误的预处理会导致 embedding 质量严重下降。当前代码已使用相同的归一化，但需要确认通道顺序（RGB vs BGR）。

### 4. 转换脚本放在项目中

**选择**: 在项目根目录添加 `scripts/convert_model.py`，一次性使用
**理由**: 让模型来源和转换过程可追溯、可复现。其他开发者 clone 项目后也能自己转换模型。

## Risks / Trade-offs

- **[ONNX → TFLite 转换可能丢失精度]** → 转换后运行一组标准测试人脸对比，验证余弦相似度分布合理
- **[InsightFace 模型仅限非商用研究]** → 当前是测试 App，满足许可要求；产品化需重新评估
- **[转换后模型大小可能增加]** → 可使用 float16 量化，TFLite 支持 post-training quantization
- **[通道顺序差异 (RGB vs BGR)]** → InsightFace 训练用 BGR，需在预处理中做通道翻转

## Migration Plan

1. 编写 `scripts/convert_model.py` 完成 ONNX → TFLite 转换
2. 运行脚本生成新的 TFLite 模型
3. 替换 `assets/models/MobileFaceNet.tflite`
4. 修改 `EmbeddingService` 适配预处理（确认通道顺序、归一化）
5. 清除旧 embedding 数据，全量重新生成
6. 验证聚类效果
