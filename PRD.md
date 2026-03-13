# FaceCluster 测试 App — 需求说明

## 目标

验证「ML Kit 检测 + MobileFaceNet embedding + DBSCAN 聚类」端侧人脸归类方案的可行性和效果。

---

## 核心功能

### 1. 照片导入
- 从手机相册选择多张照片（支持批量选择）
- 或选择一个相册/文件夹，一次性导入全部

### 2. 人脸检测
- 使用 Google ML Kit (`google_mlkit_face_detection`) 逐张扫描
- 检测到的每张人脸：
  - 裁剪 + 仿射对齐到 112×112
  - 显示检测到的人脸数量
- 展示：每张照片标注人脸框（bounding box），可浏览

### 3. 人脸 Embedding
- 使用 MobileFaceNet（TFLite 格式，~2MB）
- 每张对齐后的人脸 → 512 维 float32 向量
- 向量存入本地 SQLite（drift）

### 4. 自动聚类
- DBSCAN 算法，距离函数为 cosine similarity
- 可调参数（UI 上放两个 slider）：
  - **相似度阈值**：默认 0.6，范围 0.4-0.8
  - **最小样本数**（min_samples）：默认 2
- 输出：N 个人物组 + 1 个未分类组

### 5. 结果展示
- 列表页：每个人物组显示一张代表脸 + 照片数量
- 点进去：该人物的所有照片缩略图
- 未分类组单独展示
- **不需要**：命名、合并、拆分等编辑功能（测试阶段）

### 6. 性能统计（关键）
- 显示以下指标：
  - 总耗时（检测 / embedding / 聚类 分别计时）
  - 每张照片平均处理时间
  - 检测到的总人脸数
  - 聚类出的人物组数
  - 内存峰值占用

---

## 技术栈

| 组件 | 选型 |
|---|---|
| 框架 | Flutter 3.x |
| 人脸检测 | `google_mlkit_face_detection` |
| Embedding 推理 | `tflite_flutter` + MobileFaceNet.tflite |
| 本地存储 | drift (SQLite) |
| 图片处理 | `image` package (Dart) |
| 相册访问 | `photo_manager` 或 `image_picker` |
| 聚类 | Dart 手写 DBSCAN |

## 数据模型（SQLite）

```sql
-- 照片表
CREATE TABLE photos (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL,        -- 本地路径
  width INTEGER,
  height INTEGER,
  created_at DATETIME
);

-- 人脸表
CREATE TABLE faces (
  id INTEGER PRIMARY KEY,
  photo_id INTEGER REFERENCES photos(id),
  bbox_x REAL,               -- 检测框坐标（归一化）
  bbox_y REAL,
  bbox_w REAL,
  bbox_h REAL,
  embedding BLOB,            -- 512 × float32 = 2048 bytes
  cluster_id INTEGER          -- 聚类结果，-1 = 未分类
);
```

## 不做的事情（明确排除）

- ❌ 云端处理 / 网络请求
- ❌ 用户账号 / 登录
- ❌ 人物命名 / 手动编辑聚类
- ❌ 增量更新（每次全量重跑）
- ❌ 后台扫描（前台手动触发）


## 交付物

1. 可运行的 Flutter 项目（iOS + Android）
2. 内置 MobileFaceNet.tflite 模型文件
3. README：含编译说明 + 模型来源链接

---

