#pragma once
#include "gopost/gpu_context.h"
#include <memory>

namespace gopost {

class IGpuContext {
public:
    virtual ~IGpuContext() = default;

    virtual GopostGpuBackend backend() const = 0;
    virtual GopostError initialize() = 0;

    virtual GopostError createTexture(uint32_t width, uint32_t height,
        GopostPixelFormat format, void** outHandle) = 0;
    virtual GopostError destroyTexture(void* handle) = 0;
    virtual GopostError uploadTexture(void* handle, const uint8_t* data, size_t size) = 0;

    static std::unique_ptr<IGpuContext> createForPlatform();
};

}  // namespace gopost

struct GopostGpuContext {
    std::unique_ptr<gopost::IGpuContext> impl;
};

struct GopostTexture {
    void* handle = nullptr;
    uint32_t width = 0;
    uint32_t height = 0;
    GopostPixelFormat format = GOPOST_PIXEL_FORMAT_RGBA8;
};
