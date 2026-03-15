#ifndef GOPOST_VIDEO_TIMELINE_EVALUATOR_HPP
#define GOPOST_VIDEO_TIMELINE_EVALUATOR_HPP

#include "decoder_interface.hpp"
#include "frame_cache.hpp"
#include "timeline_model.hpp"
#include "video_compositor.hpp"
#include "gopost/types.h"
#include <memory>
#include <string>
#include <unordered_map>

struct GopostEngine;
struct GopostFramePool;

namespace gopost {
namespace video {

class FrameCache;

/** Renders the timeline at current position: gather active clips, get/cache frames, composite. */
class TimelineEvaluator {
public:
    TimelineEvaluator(GopostEngine* engine,
                     TimelineModel* model,
                     FrameCache* frame_cache);
    ~TimelineEvaluator() = default;

    /**
     * Render frame at current timeline position into output (from engine pool).
     * Caller must gopost_frame_release(output).
     */
    int render_frame(GopostFrame** output);

    /** Get or create decoder for a source path (cached per path). */
    IVideoDecoder* get_decoder_for(const std::string& path);

private:
    GopostFrame* get_clip_frame_at(const Clip* clip, double timeline_time, int64_t frame_index);
    GopostVideoBlendMode to_blend_mode(int32_t mode) const;

    GopostEngine* engine_ = nullptr;
    TimelineModel* model_ = nullptr;
    FrameCache* frame_cache_ = nullptr;
    std::unordered_map<std::string, std::unique_ptr<IVideoDecoder>> decoders_;
};

}  // namespace video
}  // namespace gopost

#endif
