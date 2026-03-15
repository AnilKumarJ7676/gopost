#include "gopost/gpu_context.h"
#include "gpu_context.cpp"

#if defined(GOPOST_PLATFORM_IOS) || defined(GOPOST_PLATFORM_MACOS)
#include "metal/metal_context.cpp"
#endif

#include "gles/gles_context.cpp"

namespace gopost {

std::unique_ptr<IGpuContext> IGpuContext::createForPlatform() {
#if defined(GOPOST_PLATFORM_IOS) || defined(GOPOST_PLATFORM_MACOS)
    return std::make_unique<MetalContext>();
#else
    return std::make_unique<GLESContext>();
#endif
}

}  // namespace gopost

extern "C" {

GopostError gopost_gpu_create_for_platform(GopostGpuContext** ctx) {
    if (!ctx) return GOPOST_ERROR_INVALID_ARGUMENT;

    auto* context = new (std::nothrow) GopostGpuContext{};
    if (!context) return GOPOST_ERROR_OUT_OF_MEMORY;

    context->impl = gopost::IGpuContext::createForPlatform();
    GopostError err = context->impl->initialize();
    if (err != GOPOST_OK) {
        delete context;
        return err;
    }

    *ctx = context;
    return GOPOST_OK;
}

GopostError gopost_gpu_destroy(GopostGpuContext* ctx) {
    if (!ctx) return GOPOST_ERROR_INVALID_ARGUMENT;
    delete ctx;
    return GOPOST_OK;
}

GopostGpuBackend gopost_gpu_get_backend(GopostGpuContext* ctx) {
    if (!ctx || !ctx->impl) return GOPOST_GPU_BACKEND_NONE;
    return ctx->impl->backend();
}

GopostError gopost_gpu_create_texture(GopostGpuContext* ctx, GopostTexture** texture,
    uint32_t width, uint32_t height, GopostPixelFormat format) {
    if (!ctx || !ctx->impl || !texture) return GOPOST_ERROR_INVALID_ARGUMENT;

    auto* tex = new (std::nothrow) GopostTexture{};
    if (!tex) return GOPOST_ERROR_OUT_OF_MEMORY;

    tex->width = width;
    tex->height = height;
    tex->format = format;

    GopostError err = ctx->impl->createTexture(width, height, format, &tex->handle);
    if (err != GOPOST_OK) {
        delete tex;
        return err;
    }

    *texture = tex;
    return GOPOST_OK;
}

GopostError gopost_gpu_destroy_texture(GopostGpuContext* ctx, GopostTexture* texture) {
    if (!ctx || !ctx->impl || !texture) return GOPOST_ERROR_INVALID_ARGUMENT;
    ctx->impl->destroyTexture(texture->handle);
    delete texture;
    return GOPOST_OK;
}

GopostError gopost_gpu_upload_texture(GopostGpuContext* ctx, GopostTexture* texture,
    const uint8_t* data, size_t data_size) {
    if (!ctx || !ctx->impl || !texture || !data) return GOPOST_ERROR_INVALID_ARGUMENT;
    return ctx->impl->uploadTexture(texture->handle, data, data_size);
}

}
