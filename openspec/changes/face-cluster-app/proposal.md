## Why

验证「ML Kit 检测 + MobileFaceNet embedding + DBSCAN 聚类」端侧人脸归类方案的可行性和效果。需要一个测试 App 来衡量端侧人脸聚类的准确度和性能表现，为后续产品化决策提供数据支撑。

## What Changes

- 新建 Flutter 项目，支持 iOS + Android
- 实现从相册批量导入照片
- 集成 Google ML Kit 进行人脸检测，裁剪对齐到 112x112
- 集成 MobileFaceNet (TFLite) 生成 512 维人脸 embedding
- 使用 drift (SQLite) 存储照片、人脸数据及 embedding 向量
- 实现 Dart 手写 DBSCAN 聚类算法（cosine similarity）
- 提供可调参数 UI（相似度阈值、最小样本数）
- 展示聚类结果：人物组列表 + 未分类组
- 展示性能统计：检测/embedding/聚类各阶段耗时、内存峰值等

## Capabilities

### New Capabilities

- `photo-import`: 从手机相册批量选择和导入照片
- `face-detection`: 使用 ML Kit 检测人脸并裁剪对齐到 112x112
- `face-embedding`: 使用 MobileFaceNet TFLite 模型生成 512 维 embedding 向量
- `face-clustering`: DBSCAN 聚类算法，支持可调参数（相似度阈值、最小样本数）
- `cluster-display`: 聚类结果展示（人物组列表、人物详情、未分类组）
- `perf-stats`: 性能统计（各阶段耗时、人脸数、组数、内存峰值）
- `local-storage`: drift (SQLite) 本地数据存储（照片表、人脸表）

### Modified Capabilities

(无 — 全新项目)

## Impact

- **依赖**: Flutter 3.x, google_mlkit_face_detection, tflite_flutter, drift, image, photo_manager
- **资源**: 内置 MobileFaceNet.tflite 模型文件 (~2MB)
- **平台**: iOS 和 Android 均需配置相册访问权限
- **代码**: 全新项目，无存量代码影响
