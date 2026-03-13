# FaceCluster 技术方案文档

> 最后更新: 2026-03-13

## 1. 系统架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      FaceCluster Pipeline                       │
│                                                                 │
│  ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌──────────┐  │
│  │  Photo   │──▶│   SCRFD   │──▶│Embedding │──▶│ DBSCAN   │  │
│  │  Import  │   │ Detection │   │Generation│   │Clustering│  │
│  │          │   │ + 5pt     │   │          │   │          │  │
│  │          │   │  Align    │   │          │   │          │  │
│  └──────────┘   └───────────┘   └──────────┘   └──────────┘  │
│  photo_manager   SCRFD TFLite    MobileFaceNet   自实现        │
│                  多尺度检测       w600k_mbf                    │
│                  5点相似变换                                    │
└─────────────────────────────────────────────────────────────────┘
```

## 2. 演进历史与关键 Bug 修复

### 2.1 v1: ML Kit + 2 点对齐 (初始版本)

- 检测器: Google ML Kit Face Detection
- 对齐: 仅用 2 点 (左眼 + 右眼) 做相似变换
- **问题**: ML Kit 只对"最显著人脸"返回轮廓数据，多人照片中其余人脸精度差
- **问题**: ML Kit 的鼻/嘴轮廓位置与 InsightFace 模板不对应，加入后相似度从 0.939 降到 0.608

### 2.2 v2: SCRFD 替换 ML Kit

- 将检测器从 ML Kit 替换为 InsightFace SCRFD (det_500m)
- 获得精确的 5 点关键点，升级为 5 点相似变换对齐
- **Bug 1: SCRFD 预处理错误** — 首次部署时输入了原始 BGR 像素 (0-255)，未做归一化。结果: 大量假阳性 (每张图 16-31 个"人脸")，关键点垃圾。修复: 改为 RGB 通道 + `(pixel - 127.5) / 128.0` 归一化
- **结果**: 检测正确了，但分组仍然很差

### 2.3 v3: 修复对齐变换符号 Bug + 多尺度检测 (当前版本)

**Bug 2 (关键): 相似变换逆映射符号错误**

对齐过程需要将输出像素映射回源图像 (逆变换)。代码中 `invB` 的符号在两行中都写反了:

```dart
// 错误 ❌
final srcX = invA * dx + (-invB) * dy + invTx;
final srcY = invB * dx + invA * dy + invTy;

// 正确 ✓
final srcX = invA * dx + invB * dy + invTx;
final srcY = (-invB) * dx + invA * dy + invTy;
```

**影响**: 对所有有旋转/倾斜的人脸，对齐图像都是扭曲的。b (旋转分量) 越大，扭曲越严重。
Python 验证管线使用了正确的对齐，所以 Python 结果正确 (0.999 vs 参考) 而手机上效果差。

**修复效果对比**:

| 指标 | 修复前 (v2) | 修复后 (v3) |
|------|-------------|-------------|
| 同一人相似度 | 0.30 ~ 0.50 | **0.58 ~ 0.82** |
| 不同人相似度 | -0.08 ~ 0.30 | **-0.10 ~ 0.09** |
| 同一人戴/不戴眼镜 | 无法区分 | **0.58 ~ 0.70** |
| 最高同人相似度 | 0.69 | **0.94** |

**Bug 3: 单尺度检测丢失小人脸**

4K 手机照片 (4096x3072) 缩放到 640x640 输入时 scale=0.156，原图中小于 ~130px 的人脸无法检测到。

修复: 添加多尺度瓦片检测:
- Level 0: 全图检测 (捕获大人脸)
- Level 1: 1280x1280 瓦片 + 25% 重叠 (scale ≈ 0.5，可检测 ~40px 人脸)
- 全局 NMS 去重

## 3. 各模块技术细节

### 3.1 人脸检测 (`scrfd_service.dart`)

**模型**: InsightFace SCRFD det_500m
- 来源: `~/.insightface/models/buffalo_sc/det_500m.onnx` → 通过 onnxsim + onnx2tf 转为 TFLite
- 大小: 1.3 MB (float16)
- 输入: `[1, 640, 640, 3]` float32, **RGB 通道**, `(pixel - 127.5) / 128.0`
- 输出: 9 个张量，3 个 FPN stride 层级 (8, 16, 32)，每个层级: scores (n,1) + bbox (n,4) + keypoints (n,10)

**ONNX → TFLite 转换过程**:
1. `onnxsim` 简化模型 (消除动态 Resize 节点)
2. `onnx2tf` 转换 (NCHW → NHWC 自动处理，通道顺序不变)
3. Python 3.12 + tensorflow 2.19.0 + onnx2tf 2.3.7
4. 验证: ONNX vs TFLite 输出 cosine similarity = 1.000000

**Anchor 解码**:
```
每个 stride 层: fmSize = 640 / stride, nAnchors = fmSize² × 2
anchor center: (col × stride, row × stride)
bbox: x1 = cx - bbox[0]*stride, y1 = cy - bbox[1]*stride, ...
keypoints: kx = cx + kps[k*2]*stride, ky = cy + kps[k*2+1]*stride
```

### 3.2 多尺度检测 (`face_detection_service.dart`)

```
if max(W, H) <= 1280:
    单次全图检测
else:
    全图检测 (大人脸)
    + 1280×1280 瓦片检测, stride=960, overlap=320 (小人脸)
    全局 NMS 去重 (IoU > 0.4 合并)
```

**实际性能** (手机端):
- 1080x1920 图片: 2 tiles, ~3.5 秒/张
- 3072x4096 图片: 12 tiles, ~11 秒/张
- 4896x6528 图片: 35 tiles, ~30 秒/张
- 7008x4672 图片: 35 tiles, ~31 秒/张 (检测到 21 张人脸)

### 3.3 质量门控 (Quality Gate)

| 条件 | 阈值 | 原因 |
|------|------|------|
| 人脸框太小 | bbox < 40×40 px | 分辨率不足，对齐不可靠 |
| 两眼距离太近 | eye_dist < 15 px | 侧脸/遮挡，关键点不可靠 |
| 两眼距/脸宽比 | ratio < 0.25 | 严重侧脸，向量不具备区分性 |

**已知遗留问题**: 部分异常检测未被过滤:
- 极度模糊/非人脸区域 (如只截到头发)
- 只截取到局部 (如仅嘴巴或仅眼睛)
- 极端侧脸 (几乎是侧面轮廓)

### 3.4 人脸对齐 — 5 点相似变换

**方法**: 最小二乘相似变换 (4 自由度: 旋转 + 均匀缩放 + 平移)

```
正变换: x' = a·x - b·y + tx,  y' = b·x + a·y + ty
逆变换: x = invA·x' + invB·y' + invTx,  y = -invB·x' + invA·y' + invTy
其中: invA = a/(a²+b²), invB = b/(a²+b²)
```

**5 个关键点 → 模板坐标 (112×112)**:

| 关键点 | 模板坐标 |
|--------|----------|
| 左眼 | (38.29, 51.70) |
| 右眼 | (73.53, 51.50) |
| 鼻尖 | (56.03, 71.74) |
| 左嘴角 | (41.55, 92.37) |
| 右嘴角 | (70.73, 92.20) |

**求解**: 构建 4×4 正规方程 (A^T·A·x = A^T·b)，高斯消元 + 部分主元选择

**插值**: 双线性插值 (Bilinear Interpolation)

### 3.5 Embedding 生成 (`embedding_service.dart`)

**模型**: InsightFace w600k_mbf (MobileFaceNet)
- 大小: 6.5 MB
- 输入: `[1, 112, 112, 3]` float32, **BGR 通道顺序**, `(pixel - 127.5) / 128.0`
- 输出: `[1, 512]` float32 → L2 归一化为单位向量

**注意**: 检测用 RGB，Embedding 用 BGR — 这是 InsightFace 原始模型的设计

### 3.6 聚类 (`clustering_service.dart`)

**算法**: DBSCAN
- `similarityThreshold` = 0.4 (UI 可调 0.4 ~ 0.8)
- `minSamples` = 1
- `eps = 1.0 - similarityThreshold`
- 距离度量: 余弦距离 = 1 - cosine_similarity

## 4. 视觉验证结果 (2026-03-13)

使用 Claude Opus 多模态能力对手机端输出的 40 张对齐人脸进行视觉审查:

### 4.1 视觉分类 (Claude)

| 人物 | 数量 | 对应 face ID |
|------|------|-------------|
| 人物 A (戴眼镜男生) | 17 | 000, 001, 013, 014, 015, 017, 024, 027, 028, 031, 032, 033, 035, 036, 037, 038, 039 |
| 人物 B (女生) | 14 | 008, 011, 012, 016, 018, 019, 020, 021, 022, 023, 025, 029, 030, 034 |
| 人物 C (不戴眼镜男生) | 5 | 003, 004, 005, 007, 010 |
| 质量差 (应过滤) | 4 | 002 (模糊), 006 (极端侧脸), 009 (仅嘴巴), 026 (仅眼睛) |

**用户确认**: 人物 A 和人物 C 是同一个人 (戴/不戴眼镜)。
模型在这种情况下给出 0.58-0.70 的相似度，正确将其归为一组。

### 4.2 相似度矩阵分析 (前 10 张)

```
         f0     f1     f2     f3     f4     f5     f6     f7     f8     f9
f0    1.000  0.732  0.028  0.648  0.577  0.581 -0.040  0.580  0.014  0.072
f1    0.732  1.000  0.053  0.694  0.633  0.610 -0.026  0.631 -0.075  0.078
f2    0.028  0.053  1.000 -0.016 -0.045 -0.026  0.178 -0.022  0.001 -0.023
f3    0.648  0.694 -0.016  1.000  0.781  0.680 -0.063  0.696 -0.013  0.061
f4    0.577  0.633 -0.045  0.781  1.000  0.659 -0.009  0.705 -0.068  0.093
f5    0.581  0.610 -0.026  0.680  0.659  1.000 -0.046  0.824 -0.057  0.012
f6   -0.040 -0.026  0.178 -0.063 -0.009 -0.046  1.000 -0.065 -0.096 -0.072
f7    0.580  0.631 -0.022  0.696  0.705  0.824 -0.065  1.000  0.018 -0.014
f8    0.014 -0.075  0.001 -0.013 -0.068 -0.057 -0.096  0.018  1.000  0.016
f9    0.072  0.078 -0.023  0.061  0.093  0.012 -0.072 -0.014  0.016  1.000
```

- face[0,1,3,4,5,7] (人物 A = 人物 C): 互相似度 0.58-0.82 → 正确合并为一簇
- face[2] (模糊): 与所有人 < 0.18 → 正确隔离为噪声
- face[6] (极端侧脸): 与所有人 < 0.18 → 正确隔离为噪声
- face[8] (女生): 与所有人 < 0.02 → 隔离为噪声 (因前 10 张中只有她一个女生)
- face[9]: 与所有人 < 0.09 → 隔离为噪声

## 5. 遗留问题与优化方向

### 5.1 质量过滤不足 [中优先级]

4 张低质量检测未被当前质量门控过滤:
- face_002: 极度模糊 → 需增加模糊度检测 (如 Laplacian 方差)
- face_006: 极端侧脸 → 需更严格的侧脸检测
- face_009: 仅截取到嘴巴 → 需验证关键点分布合理性
- face_026: 仅截取到眼睛 → 需验证 bbox 与关键点的一致性

### 5.2 大图处理速度慢 [中优先级]

4896x6528 图片需要 35 个瓦片 × ~0.8 秒 ≈ 30 秒。可优化:
- 限制最大处理分辨率 (如先降采样到 3000px 再瓦片)
- 使用 GPU delegate 加速 TFLite 推理
- 跳过全图检测 (当 scale < 0.2 时全图检测价值不大)

### 5.3 DBSCAN 局限 [低优先级]

- minSamples=1 时等效于单链接聚类，可能产生链式传递
- O(n²) 复杂度，人脸数量超过几百时会变慢
- 可考虑替换为 Chinese Whispers 或层次聚类

### 5.4 调试功能 [临时]

当前版本包含调试用的人脸图像保存功能 (`processing_service.dart`)，保存到:
```
/storage/emulated/0/Android/data/com.example.face_cluster/files/debug_faces/
```
正式发布前应移除。

## 6. 文件清单

| 文件 | 职责 |
|------|------|
| `lib/services/scrfd_service.dart` | SCRFD 人脸检测、NMS |
| `lib/services/face_detection_service.dart` | 多尺度检测、质量门控、5 点相似变换对齐 |
| `lib/services/embedding_service.dart` | MobileFaceNet 推理、BGR 预处理、L2 归一化 |
| `lib/services/clustering_service.dart` | DBSCAN 聚类 |
| `lib/services/processing_service.dart` | 管线编排、进度回调、调试输出 |
| `lib/screens/home_screen.dart` | UI、参数调整、触发处理 |
| `lib/screens/results_screen.dart` | 聚类结果展示 |
| `lib/models/database.dart` | Drift 数据库 (photos, faces, embeddings) |
| `assets/models/scrfd_500m.tflite` | SCRFD det_500m (1.3MB float16) |
| `assets/models/MobileFaceNet.tflite` | InsightFace w600k_mbf (6.5MB) |
| `docs/technical_design.md` | 本文档 |
