## 1. Model Conversion

- [x] 1.1 Create `scripts/convert_model.py` — 下载 InsightFace buffalo_sc 包并提取 w600k_mbf.onnx
- [x] 1.2 实现 ONNX → TF SavedModel → TFLite 转换逻辑
- [x] 1.3 添加转换后的模型验证（打印 input/output shape，确认 [1,112,112,3] → [1,512]）
- [x] 1.4 运行转换脚本，生成新的 MobileFaceNet.tflite 并替换 assets/models/ 中的旧文件

## 2. EmbeddingService 适配

- [x] 2.1 修改 `embedding_service.dart` 输入预处理：RGB → BGR 通道翻转
- [x] 2.2 确认归一化参数与 InsightFace 一致：(pixel - 127.5) / 128.0
- [x] 2.3 验证模型加载后 output shape 为 512 维
- [x] 2.4 删除旧的维度自动检测兜底逻辑，明确要求 512 维

## 3. 验证

- [ ] 3.1 在真机上加载新模型，确认推理无报错
- [ ] 3.2 对比同一人两张照片的 embedding 余弦相似度（应 > 0.5）
- [ ] 3.3 对比不同人照片的 embedding 余弦相似度（应 < 0.3）
- [ ] 3.4 运行完整聚类流程，确认结果合理
