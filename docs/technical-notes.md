# FaceCluster 技术笔记

## 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    MainShell                         │
│  ┌──────────────────┐  ┌──────────────────────────┐ │
│  │   ClusterTab     │  │   BenchmarkScreen        │ │
│  │                  │  │                          │ │
│  │  PhotoSelection  │  │  Timing / Memory Charts  │ │
│  │  Processing      │  │  Detection Overlay       │ │
│  │  Results         │  │  Detail Cards            │ │
│  └──────────────────┘  └──────────────────────────┘ │
│              BottomNavigationBar                     │
└─────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────┐
│               BackendRegistry                        │
│  ┌─────────────┐        ┌─────────────┐            │
│  │   TFLite     │        │    NCNN     │            │
│  │  Detector    │        │  Detector   │            │
│  │  Embedder    │        │  Embedder   │            │
│  └──────┬──────┘        └──────┬──────┘            │
│         │ tflite_flutter       │ Dart FFI           │
│         ▼                      ▼                    │
│  TensorFlowLiteC         ncnn_bridge.c              │
│  (CocoaPods/Gradle)      (NDK .so / iOS static)     │
└─────────────────────────────────────────────────────┘
```

- **BackendRegistry**: 工厂模式管理多后端。`register()` 注册 detector + embedder 工厂函数，`createDetectorFor(name)` 按需创建实例。
- **MainShell**: `IndexedStack` + `BottomNavigationBar`，Cluster 和 Benchmark 两个平级 Tab，切换时保持状态。

## 关键技术发现

### 1. 原生内存测量：mallinfo vs ProcessInfo.currentRss

**问题**: Dart 的 `ProcessInfo.currentRss` 无法准确捕获 TFLite/NCNN 等 native 库的堆内存分配。测出来 TFLite peak memory 接近 0。

**解决方案**: 在 C bridge 中实现 `ncnn_bridge_get_native_heap_bytes()`，通过 FFI 调用：

| 平台 | API | 测量内容 |
|------|-----|---------|
| Android | `mallinfo().uordblks` | C/C++ 堆已分配字节数 |
| iOS | `task_info(MACH_TASK_BASIC_INFO)` → `resident_size` | 进程常驻内存 |

**要点**: 在 `loadModel()` 之前采集 baseline，在 warmup 和每次推理后采集 peak，差值即为模型占用。

### 2. NCNN 原生计时：preprocess vs inference 拆分

**问题**: NCNN 的 preprocess（resize + normalize）在 C bridge 的 `ncnn_bridge_detect()` 内部完成，Dart 侧只能测到总时间，无法拆分。

**解决方案**: 在 C 代码中使用 `clock_gettime(CLOCK_MONOTONIC)` 分段计时，通过 `float* out_timing` 参数返回：
- `out_timing[0]` = preprocess ms（`ncnn_mat_from_pixels_resize` + `substract_mean_normalize`）
- `out_timing[1]` = inference ms（`ncnn_extractor_extract` 所有输出层）

iOS 10+ 支持 `clock_gettime(CLOCK_MONOTONIC)`，无需额外适配。

### 3. Letterbox vs Stretch 预处理差异

**这是一个容易引入 bug 的关键差异。**

| | TFLite | NCNN |
|---|--------|------|
| 预处理方式 | **Letterbox**（保持宽高比 + padding） | **Stretch**（直接拉伸到 640x640） |
| 缩放因子 | `scale = min(640/w, 640/h)` 统一缩放 | `scaleX = 640/w`, `scaleY = 640/h` 分别缩放 |
| 坐标还原 | `x / scale + offsetX` | `x / scaleX` |

**曾经的 bug**: NCNN 检测框在非正方形图片上有偏移。原因是坐标还原错误地使用了 `min(scaleX, scaleY)`（letterbox 的做法），修正为独立的 `scaleX` 和 `scaleY`。

```dart
// 错误（letterbox 模式）:
final scale = min(_inputSize / width, _inputSize / height);
final x1 = (cx - bboxes[bi] * stride) / scale;

// 正确（stretch 模式）:
final scaleX = _inputSize / width;
final scaleY = _inputSize / height;
final x1 = (cx - bboxes[bi] * stride) / scaleX;
final y1 = (cy - bboxes[bi + 1] * stride) / scaleY;
```

### 4. 跨平台 ncnn_bridge.c

单一 C 文件通过条件编译支持 Android 和 iOS：

```c
// 日志
#ifdef __ANDROID__
  #define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#elif defined(__APPLE__)
  #define LOGI(...) do { fprintf(stderr, "[NCNN_BRIDGE] "); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#endif

// 内存测量
#ifdef __ANDROID__
  struct mallinfo info = mallinfo();
  return (long)info.uordblks;
#elif defined(__APPLE__)
  struct mach_task_basic_info info;
  task_info(mach_task_self(), MACH_TASK_BASIC_INFO, ...);
  return (long)info.resident_size;
#endif

// 头文件
#ifdef __APPLE__
  #include <ncnn/c_api.h>      // Framework Headers
#else
  #include "ncnn/include/c_api.h"  // NDK 本地路径
#endif
```

**注意**: iOS 不能使用 `os_log` 做 variadic format（编译器要求静态字符串字面量），改用 `fprintf(stderr, ...)`。

### 5. iOS FFI 加载方式

```dart
if (Platform.isAndroid) {
  _lib = DynamicLibrary.open('libncnn_bridge.so');  // 动态库
} else if (Platform.isIOS) {
  _lib = DynamicLibrary.process();  // 静态链接，从主进程查找符号
}
```

iOS 上 ncnn_bridge.c 通过 CocoaPods 本地 pod 编译为静态库，链接到 Runner target。符号在主进程中可直接查找。

### 6. iOS 构建配置

```
ios/
├── Podfile                    # Flutter 标准 + NcnnBridge pod
├── NcnnBridge/
│   ├── NcnnBridge.podspec     # 编译 ncnn_bridge.c, 链接框架
│   └── ncnn_bridge.c → ../../android/app/src/main/cpp/ncnn_bridge.c (symlink)
├── Frameworks/
│   ├── ncnn.framework/        # arm64 静态库 + headers
│   └── openmp.framework/      # arm64 静态库
└── Flutter/
    ├── Debug.xcconfig          # 包含 Pods xcconfig
    └── Release.xcconfig
```

NCNN iOS 预编译库来自 [Tencent/ncnn Releases](https://github.com/Tencent/ncnn/releases)（20250428），仅包含 arm64 device 架构，不支持模拟器。

## 模型信息

| 模型 | 用途 | 格式 | 输入尺寸 |
|------|------|------|---------|
| SCRFD-500M | 人脸检测 | `.tflite` / `.param`+`.bin` | 640x640 |
| MobileFaceNet | 人脸特征提取 | `.tflite` / `.param`+`.bin` | 112x112 |

- SCRFD-500M: 轻量级人脸检测，9 个输出层（3 stride × {score, bbox, kps}），stride = 8/16/32
- MobileFaceNet: 128 维人脸特征向量，用于聚类

## 性能基准测试流程

1. 选择测试照片（photo_manager）
2. 对每个注册后端（TFLite、NCNN）：
   - 记录 native heap baseline
   - 加载模型
   - Warmup 1 次
   - 运行 3 次推理取平均
   - 记录 peak memory
3. 展示：Timing 对比柱状图、Native Heap 柱状图、检测结果叠加标注、详细数据卡片
