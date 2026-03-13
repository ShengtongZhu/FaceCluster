#include <stdlib.h>
#include <string.h>
#include <time.h>

// --- Platform-specific includes ---
#ifdef __ANDROID__
#include <malloc.h>
#include <android/log.h>
#define LOG_TAG "NCNN_BRIDGE"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#elif defined(__APPLE__)
#include <stdio.h>
#include <mach/mach.h>
#define LOGI(...) do { fprintf(stderr, "[NCNN_BRIDGE] "); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#define LOGE(...) do { fprintf(stderr, "[NCNN_BRIDGE ERROR] "); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#else
#define LOGI(...)
#define LOGE(...)
#endif

#ifdef __APPLE__
#include <ncnn/c_api.h>
#else
#include "ncnn/include/c_api.h"
#endif

// ============================================================
// NCNN Bridge for Dart FFI
// Provides minimal C API for model loading, preprocessing, and inference.
// Post-processing (anchor decode, NMS, L2 norm) is done in Dart.
// ============================================================

// --- Native heap measurement ---

long ncnn_bridge_get_native_heap_bytes(void) {
#ifdef __ANDROID__
    struct mallinfo info = mallinfo();
    return (long)info.uordblks;  // total allocated bytes in native heap
#elif defined(__APPLE__)
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                                 (task_info_t)&info, &count);
    if (kr == KERN_SUCCESS) {
        return (long)info.resident_size;
    }
    return 0;
#else
    return 0;
#endif
}

// --- Net handle management ---

ncnn_net_t ncnn_bridge_create_net(int num_threads) {
    ncnn_net_t net = ncnn_net_create();
    ncnn_option_t opt = ncnn_option_create();
    ncnn_option_set_num_threads(opt, num_threads);
    ncnn_option_set_use_vulkan_compute(opt, 0);
    ncnn_net_set_option(net, opt);
    ncnn_option_destroy(opt);
    return net;
}

int ncnn_bridge_load_model(ncnn_net_t net,
                           const unsigned char* param_data, int param_len,
                           const unsigned char* model_data, int model_len) {
    LOGI("load_model: param_len=%d, model_len=%d", param_len, model_len);

    // ncnn_net_load_param_memory expects null-terminated string
    char* param_buf = (char*)malloc(param_len + 1);
    memcpy(param_buf, param_data, param_len);
    param_buf[param_len] = '\0';

    int ret = ncnn_net_load_param_memory(net, param_buf);
    LOGI("load_param ret=%d", ret);
    free(param_buf);
    if (ret != 0) return -1;

    ret = ncnn_net_load_model_memory(net, model_data);
    LOGI("load_model ret=%d", ret);
    // load_model_memory returns 0 on success or number of bytes read (implementation varies)
    // Only negative values indicate error
    if (ret < 0) return -2;
    return 0;
}

void ncnn_bridge_destroy_net(ncnn_net_t net) {
    ncnn_net_destroy(net);
}

// --- Timing helper ---
// clock_gettime(CLOCK_MONOTONIC) is available on iOS 10+ and all Android versions.

static double _now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
}

// --- Detection inference ---
// Returns flattened float array: [out0_data..., out1_data..., ..., out8_data...]
// out_sizes[i] = number of floats in output i
// out_timing[0] = preprocess ms (resize + normalize)
// out_timing[1] = inference ms (extract outputs)
// Returns total number of floats written, or -1 on error.

int ncnn_bridge_detect(ncnn_net_t net,
                       const unsigned char* rgb_pixels,
                       int img_w, int img_h,
                       int target_w, int target_h,
                       const float* mean_vals, const float* norm_vals,
                       const char* input_name,
                       const char** output_names, int num_outputs,
                       float* out_buffer, int* out_sizes, int max_buffer_size,
                       float* out_timing) {

    // --- Preprocess: resize + normalize ---
    double t0 = _now_ms();

    ncnn_mat_t mat_in = ncnn_mat_from_pixels_resize(
        rgb_pixels, NCNN_MAT_PIXEL_RGB, img_w, img_h, img_w * 3,
        target_w, target_h, NULL);

    if (!mat_in) return -1;

    ncnn_mat_substract_mean_normalize(mat_in, mean_vals, norm_vals);

    double t1 = _now_ms();
    if (out_timing) out_timing[0] = (float)(t1 - t0);

    // --- Inference: extract outputs ---
    ncnn_extractor_t ex = ncnn_extractor_create(net);
    ncnn_extractor_input(ex, input_name, mat_in);

    int total_floats = 0;
    for (int i = 0; i < num_outputs; i++) {
        ncnn_mat_t mat_out = NULL;
        int ret = ncnn_extractor_extract(ex, output_names[i], &mat_out);
        if (ret != 0 || !mat_out) {
            out_sizes[i] = 0;
            continue;
        }

        int w = ncnn_mat_get_w(mat_out);
        int h = ncnn_mat_get_h(mat_out);
        int c = ncnn_mat_get_c(mat_out);
        int size = w * h * c;

        if (total_floats + size > max_buffer_size) {
            ncnn_mat_destroy(mat_out);
            ncnn_extractor_destroy(ex);
            ncnn_mat_destroy(mat_in);
            return -1;
        }

        // Copy output data - ncnn stores data per-channel
        for (int ch = 0; ch < c; ch++) {
            const float* channel_data = ncnn_mat_get_channel_data(mat_out, ch);
            memcpy(out_buffer + total_floats + ch * w * h, channel_data, w * h * sizeof(float));
        }

        out_sizes[i] = size;
        total_floats += size;
        ncnn_mat_destroy(mat_out);
    }

    double t2 = _now_ms();
    if (out_timing) out_timing[1] = (float)(t2 - t1);

    ncnn_extractor_destroy(ex);
    ncnn_mat_destroy(mat_in);
    return total_floats;
}

// --- Embedding inference ---
// Returns 0 on success, -1 on error.

int ncnn_bridge_embed(ncnn_net_t net,
                      const unsigned char* bgr_pixels,
                      int img_w, int img_h,
                      const float* mean_vals, const float* norm_vals,
                      const char* input_name,
                      const char* output_name,
                      float* out_embedding, int embedding_dim) {

    ncnn_mat_t mat_in = ncnn_mat_from_pixels(
        bgr_pixels, NCNN_MAT_PIXEL_BGR, img_w, img_h, img_w * 3, NULL);

    if (!mat_in) return -1;

    ncnn_mat_substract_mean_normalize(mat_in, mean_vals, norm_vals);

    ncnn_extractor_t ex = ncnn_extractor_create(net);
    ncnn_extractor_input(ex, input_name, mat_in);

    ncnn_mat_t mat_out = NULL;
    int ret = ncnn_extractor_extract(ex, output_name, &mat_out);
    if (ret != 0 || !mat_out) {
        ncnn_extractor_destroy(ex);
        ncnn_mat_destroy(mat_in);
        return -1;
    }

    int w = ncnn_mat_get_w(mat_out);
    if (w != embedding_dim) {
        ncnn_extractor_destroy(ex);
        ncnn_mat_destroy(mat_out);
        ncnn_mat_destroy(mat_in);
        return -1;
    }

    const float* data = ncnn_mat_get_channel_data(mat_out, 0);
    memcpy(out_embedding, data, embedding_dim * sizeof(float));

    ncnn_mat_destroy(mat_out);
    ncnn_extractor_destroy(ex);
    ncnn_mat_destroy(mat_in);
    return 0;
}
