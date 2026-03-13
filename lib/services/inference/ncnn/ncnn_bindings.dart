import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// NCNN C API type aliases
typedef NcnnNet = Pointer<Void>;

// C function signatures
typedef NcnnBridgeCreateNetC = Pointer<Void> Function(Int32 numThreads);
typedef NcnnBridgeCreateNetDart = Pointer<Void> Function(int numThreads);

typedef NcnnBridgeLoadModelC = Int32 Function(
    Pointer<Void> net,
    Pointer<Uint8> paramData, Int32 paramLen,
    Pointer<Uint8> modelData, Int32 modelLen);
typedef NcnnBridgeLoadModelDart = int Function(
    Pointer<Void> net,
    Pointer<Uint8> paramData, int paramLen,
    Pointer<Uint8> modelData, int modelLen);

typedef NcnnBridgeDestroyNetC = Void Function(Pointer<Void> net);
typedef NcnnBridgeDestroyNetDart = void Function(Pointer<Void> net);

typedef NcnnBridgeDetectC = Int32 Function(
    Pointer<Void> net,
    Pointer<Uint8> rgbPixels,
    Int32 imgW, Int32 imgH,
    Int32 targetW, Int32 targetH,
    Pointer<Float> meanVals, Pointer<Float> normVals,
    Pointer<Utf8> inputName,
    Pointer<Pointer<Utf8>> outputNames, Int32 numOutputs,
    Pointer<Float> outBuffer, Pointer<Int32> outSizes, Int32 maxBufferSize,
    Pointer<Float> outTiming);
typedef NcnnBridgeDetectDart = int Function(
    Pointer<Void> net,
    Pointer<Uint8> rgbPixels,
    int imgW, int imgH,
    int targetW, int targetH,
    Pointer<Float> meanVals, Pointer<Float> normVals,
    Pointer<Utf8> inputName,
    Pointer<Pointer<Utf8>> outputNames, int numOutputs,
    Pointer<Float> outBuffer, Pointer<Int32> outSizes, int maxBufferSize,
    Pointer<Float> outTiming);

typedef NcnnBridgeEmbedC = Int32 Function(
    Pointer<Void> net,
    Pointer<Uint8> bgrPixels,
    Int32 imgW, Int32 imgH,
    Pointer<Float> meanVals, Pointer<Float> normVals,
    Pointer<Utf8> inputName,
    Pointer<Utf8> outputName,
    Pointer<Float> outEmbedding, Int32 embeddingDim);
typedef NcnnBridgeEmbedDart = int Function(
    Pointer<Void> net,
    Pointer<Uint8> bgrPixels,
    int imgW, int imgH,
    Pointer<Float> meanVals, Pointer<Float> normVals,
    Pointer<Utf8> inputName,
    Pointer<Utf8> outputName,
    Pointer<Float> outEmbedding, int embeddingDim);

typedef NcnnBridgeGetNativeHeapBytesC = Int64 Function();
typedef NcnnBridgeGetNativeHeapBytesDart = int Function();

/// Lazily loaded NCNN bridge bindings.
class NcnnBindings {
  static NcnnBindings? _instance;
  static NcnnBindings get instance => _instance ??= NcnnBindings._();

  late final DynamicLibrary _lib;
  late final NcnnBridgeCreateNetDart createNet;
  late final NcnnBridgeLoadModelDart loadModel;
  late final NcnnBridgeDestroyNetDart destroyNet;
  late final NcnnBridgeDetectDart detect;
  late final NcnnBridgeEmbedDart embed;
  late final NcnnBridgeGetNativeHeapBytesDart getNativeHeapBytes;

  bool get isAvailable => _available;
  bool _available = false;

  NcnnBindings._() {
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libncnn_bridge.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else {
        _available = false;
        return;
      }

      createNet = _lib
          .lookupFunction<NcnnBridgeCreateNetC, NcnnBridgeCreateNetDart>(
              'ncnn_bridge_create_net');
      loadModel = _lib
          .lookupFunction<NcnnBridgeLoadModelC, NcnnBridgeLoadModelDart>(
              'ncnn_bridge_load_model');
      destroyNet = _lib
          .lookupFunction<NcnnBridgeDestroyNetC, NcnnBridgeDestroyNetDart>(
              'ncnn_bridge_destroy_net');
      detect = _lib
          .lookupFunction<NcnnBridgeDetectC, NcnnBridgeDetectDart>(
              'ncnn_bridge_detect');
      embed = _lib
          .lookupFunction<NcnnBridgeEmbedC, NcnnBridgeEmbedDart>(
              'ncnn_bridge_embed');
      getNativeHeapBytes = _lib
          .lookupFunction<NcnnBridgeGetNativeHeapBytesC, NcnnBridgeGetNativeHeapBytesDart>(
              'ncnn_bridge_get_native_heap_bytes');

      _available = true;
    } catch (e) {
      print('[NCNN] Failed to load native library: $e');
      _available = false;
    }
  }
}
