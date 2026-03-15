#ifndef GOPOST_VIDEO_DECODER_INTERFACE_HPP
#define GOPOST_VIDEO_DECODER_INTERFACE_HPP

#include "gopost/types.h"
#include <cstdint>
#include <memory>
#include <string>

struct GopostEngine;
/* GopostFrame from gopost/types.h */

namespace gopost {
namespace video {

/** Video stream info after open. */
struct VideoStreamInfo {
    int32_t width = 0;
    int32_t height = 0;
    double frame_rate = 30.0;
    double duration_seconds = 0;
    int64_t frame_count = 0;
};

/** Abstract video decoder: open file, seek/decode frame, close. */
class IVideoDecoder {
public:
    virtual ~IVideoDecoder() = default;
    /** Open file; return true on success. */
    virtual bool open(const std::string& path) = 0;
    virtual void close() = 0;
    virtual bool is_open() const = 0;
    virtual VideoStreamInfo info() const = 0;
    /**
     * Decode frame at source time (seconds). Returns frame from engine pool; caller must release.
     * Returns nullptr on error or unsupported.
     */
    virtual GopostFrame* decode_frame_at(double source_time_seconds) = 0;
};

/** Factory: returns a decoder instance (e.g. stub or FFmpeg). Engine used for frame pool. */
std::unique_ptr<IVideoDecoder> create_video_decoder(GopostEngine* engine);

}  // namespace video
}  // namespace gopost

#endif
