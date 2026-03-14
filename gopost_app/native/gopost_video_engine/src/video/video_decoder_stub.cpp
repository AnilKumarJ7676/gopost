#if !defined(__APPLE__)
#include "decoder_interface.hpp"
#include "gopost/engine.h"
#include "gopost/error.h"
#include <cstring>
#include <cmath>

namespace gopost {
namespace video {

class StubVideoDecoder : public IVideoDecoder {
public:
    explicit StubVideoDecoder(GopostEngine* engine) : engine_(engine) {}
    bool open(const std::string& path) override {
        path_ = path;
        if (path.empty()) return false;
        info_.width = 1920;
        info_.height = 1080;
        info_.frame_rate = 30.0;
        info_.duration_seconds = 10.0;
        info_.frame_count = 300;
        return true;
    }
    void close() override { path_.clear(); }
    bool is_open() const override { return !path_.empty(); }
    VideoStreamInfo info() const override { return info_; }
    GopostFrame* decode_frame_at(double source_time_seconds) override {
        if (!engine_ || !is_open()) return nullptr;
        GopostFrame* frame = nullptr;
        if (gopost_frame_acquire(engine_, &frame, (uint32_t)info_.width, (uint32_t)info_.height,
                                 GOPOST_PIXEL_FORMAT_RGBA8) != GOPOST_OK) {
            return nullptr;
        }
        if (!frame || !frame->data) return nullptr;
        const size_t n = (size_t)frame->width * frame->height * 4;
        const double t = std::fmod(source_time_seconds, 1.0);
        uint8_t r = static_cast<uint8_t>(t * 255);
        uint8_t g = 80;
        uint8_t b = 180;
        uint8_t a = 255;
        for (size_t i = 0; i < n; i += 4) {
            frame->data[i] = r;
            frame->data[i + 1] = g;
            frame->data[i + 2] = b;
            frame->data[i + 3] = a;
        }
        return frame;
    }
private:
    GopostEngine* engine_ = nullptr;
    std::string path_;
    VideoStreamInfo info_;
};

std::unique_ptr<IVideoDecoder> create_video_decoder(GopostEngine* engine) {
    return std::make_unique<StubVideoDecoder>(engine);
}

}  // namespace video
}  // namespace gopost
#endif
