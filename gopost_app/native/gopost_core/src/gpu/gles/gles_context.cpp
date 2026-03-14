#include "../gpu_context.cpp"

namespace gopost {

class GLESContext : public IGpuContext {
public:
    GopostGpuBackend backend() const override { return GOPOST_GPU_BACKEND_GLES; }

    GopostError initialize() override {
        initialized_ = true;
        return GOPOST_OK;
    }

    GopostError createTexture(uint32_t /*width*/, uint32_t /*height*/,
        GopostPixelFormat /*format*/, void** outHandle) override {
        if (!initialized_) return GOPOST_ERROR_NOT_INITIALIZED;
        static int textureCounter = 0;
        *outHandle = reinterpret_cast<void*>(static_cast<intptr_t>(++textureCounter));
        return GOPOST_OK;
    }

    GopostError destroyTexture(void* /*handle*/) override {
        return GOPOST_OK;
    }

    GopostError uploadTexture(void* handle, const uint8_t* /*data*/, size_t /*size*/) override {
        if (!handle) return GOPOST_ERROR_INVALID_ARGUMENT;
        return GOPOST_OK;
    }

private:
    bool initialized_ = false;
};

}  // namespace gopost
