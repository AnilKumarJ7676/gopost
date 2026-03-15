#ifndef GOPOST_GPU_CONTEXT_H
#define GOPOST_GPU_CONTEXT_H

#include "gopost/types.h"
#include "gopost/error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    GOPOST_GPU_BACKEND_NONE = 0,
    GOPOST_GPU_BACKEND_METAL = 1,
    GOPOST_GPU_BACKEND_VULKAN = 2,
    GOPOST_GPU_BACKEND_GLES = 3,
    GOPOST_GPU_BACKEND_WEBGL = 4,
} GopostGpuBackend;

typedef struct GopostGpuContext GopostGpuContext;
typedef struct GopostTexture GopostTexture;
typedef struct GopostPipeline GopostPipeline;

GopostError gopost_gpu_create_for_platform(GopostGpuContext** ctx);
GopostError gopost_gpu_destroy(GopostGpuContext* ctx);
GopostGpuBackend gopost_gpu_get_backend(GopostGpuContext* ctx);

GopostError gopost_gpu_create_texture(GopostGpuContext* ctx, GopostTexture** texture,
    uint32_t width, uint32_t height, GopostPixelFormat format);
GopostError gopost_gpu_destroy_texture(GopostGpuContext* ctx, GopostTexture* texture);

GopostError gopost_gpu_upload_texture(GopostGpuContext* ctx, GopostTexture* texture,
    const uint8_t* data, size_t data_size);

#ifdef __cplusplus
}
#endif

#endif
