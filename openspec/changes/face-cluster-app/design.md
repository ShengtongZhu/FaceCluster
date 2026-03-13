## Context

全新 Flutter 测试项目，目标是验证端侧人脸聚类方案的可行性。无存量代码，从零搭建。核心技术链路：相册照片 → ML Kit 人脸检测 → 裁剪对齐 → MobileFaceNet embedding → DBSCAN 聚类 → 结果展示。

所有处理在本地完成，无网络依赖。数据存储使用 drift (SQLite)。

## Goals / Non-Goals

**Goals:**
- 构建可运行的 iOS + Android Flutter App
- 完整实现端侧人脸检测 → embedding → 聚类流水线
- 提供性能统计数据（各阶段耗时、内存占用）供评估
- 支持用户调节聚类参数以观察效果变化

**Non-Goals:**
- 不做云端处理或网络请求
- 不做用户账号/登录体系
- 不做人物命名/手动编辑聚类
- 不做增量更新（每次全量重跑）
- 不做后台扫描（前台手动触发）
- 不追求生产级别的 UI/UX 设计

## Decisions

### 1. 人脸检测选型：Google ML Kit

**选择**: `google_mlkit_face_detection`
**理由**: Flutter 生态中最成熟的端侧人脸检测方案，支持 iOS/Android 双端，检测精度高，API 简洁。
**替代方案**: 自训练模型 (维护成本高)、MediaPipe (Flutter 集成不够成熟)。

### 2. Embedding 模型：MobileFaceNet (TFLite)

**选择**: MobileFaceNet.tflite (~2MB)，输出 512 维 float32 向量
**理由**: 模型小、推理快、精度足够验证方案。TFLite 在移动端有良好的硬件加速支持。
**替代方案**: ArcFace (模型较大 ~100MB)、FaceNet (同样较大)。

### 3. 人脸对齐策略：仿射变换 112x112

**选择**: 基于 ML Kit 检测到的人脸关键点进行仿射变换，对齐到 112x112 尺寸
**理由**: MobileFaceNet 的标准输入尺寸，对齐可显著提升 embedding 质量。
**替代方案**: 简单裁剪 (精度下降明显)。

### 4. 聚类算法：Dart 手写 DBSCAN

**选择**: 纯 Dart 实现 DBSCAN，距离函数为 cosine similarity
**理由**: DBSCAN 不需要预设聚类数量，适合人脸聚类场景。算法实现简单，纯 Dart 避免平台桥接开销。
**替代方案**: K-Means (需预设 K 值)、HDBSCAN (实现复杂度高)。

### 5. 存储方案：drift (SQLite)

**选择**: drift 作为 SQLite ORM
**理由**: 类型安全、编译时验证查询、Flutter 生态主流选择。embedding 以 BLOB 存储 (512 × 4 = 2048 bytes/face)。
**替代方案**: sqflite (API 原始)、Hive (不适合关系数据)。

### 6. 图片处理：Dart image package

**选择**: `image` package 在 Dart 层做裁剪和仿射变换
**理由**: 跨平台一致，API 简洁，满足 112x112 小图处理需求。
**替代方案**: 平台原生处理 (需写 platform channel，增加复杂度)。

### 7. 应用架构：单页面流程式

**选择**: 简单的页面结构：首页（导入+触发处理）→ 结果页（聚类展示）→ 详情页（人物照片）
**理由**: 测试 App 不需要复杂导航，流程线性，降低开发复杂度。状态管理使用 Provider 或 Riverpod。

## Risks / Trade-offs

- **[大量照片处理可能 OOM]** → 分批处理照片，每批释放内存；UI 展示处理进度
- **[Dart image package 性能较慢]** → 对于 112x112 小图可接受；如遇瓶颈可改用 platform channel
- **[ML Kit 在不同设备上的检测差异]** → 测试阶段可接受，记录设备信息
- **[DBSCAN 对参数敏感]** → 提供 UI slider 让用户调节，便于找到最佳参数
- **[TFLite 在某些设备上无 GPU 加速]** → 回退到 CPU 推理，耗时会增加但功能不受影响
