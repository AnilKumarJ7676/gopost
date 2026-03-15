#if !defined(__APPLE__) && defined(GOPOST_HAS_FFMPEG)
#include "decoder_interface.hpp"
#include "gopost/engine.h"
#include "gopost/error.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
}

#include <string>
#include <cstring>

namespace gopost {
namespace video {

class FFmpegVideoDecoder : public IVideoDecoder {
public:
    explicit FFmpegVideoDecoder(GopostEngine* engine) : engine_(engine) {}

    ~FFmpegVideoDecoder() override { close(); }

    bool open(const std::string& path) override {
        close();
        if (path.empty() || !engine_) return false;

        if (avformat_open_input(&fmt_ctx_, path.c_str(), nullptr, nullptr) < 0)
            return false;

        if (avformat_find_stream_info(fmt_ctx_, nullptr) < 0) {
            close();
            return false;
        }

        video_stream_idx_ = av_find_best_stream(
            fmt_ctx_, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
        if (video_stream_idx_ < 0) {
            close();
            return false;
        }

        AVStream* stream = fmt_ctx_->streams[video_stream_idx_];
        const AVCodec* codec = avcodec_find_decoder(stream->codecpar->codec_id);
        if (!codec) {
            close();
            return false;
        }

        codec_ctx_ = avcodec_alloc_context3(codec);
        if (!codec_ctx_) {
            close();
            return false;
        }

        if (avcodec_parameters_to_context(codec_ctx_, stream->codecpar) < 0) {
            close();
            return false;
        }

        codec_ctx_->thread_count = 0;
        if (avcodec_open2(codec_ctx_, codec, nullptr) < 0) {
            close();
            return false;
        }

        info_.width = codec_ctx_->width;
        info_.height = codec_ctx_->height;

        if (stream->avg_frame_rate.den > 0 && stream->avg_frame_rate.num > 0) {
            info_.frame_rate = av_q2d(stream->avg_frame_rate);
        } else if (stream->r_frame_rate.den > 0 && stream->r_frame_rate.num > 0) {
            info_.frame_rate = av_q2d(stream->r_frame_rate);
        } else {
            info_.frame_rate = 30.0;
        }

        if (fmt_ctx_->duration > 0) {
            info_.duration_seconds = (double)fmt_ctx_->duration / AV_TIME_BASE;
        } else if (stream->duration > 0 && stream->time_base.den > 0) {
            info_.duration_seconds = (double)stream->duration * av_q2d(stream->time_base);
        } else {
            info_.duration_seconds = 0;
        }

        info_.frame_count = (int64_t)(info_.duration_seconds * info_.frame_rate);

        sws_ctx_ = sws_getContext(
            info_.width, info_.height, codec_ctx_->pix_fmt,
            info_.width, info_.height, AV_PIX_FMT_RGBA,
            SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_) {
            close();
            return false;
        }

        frame_ = av_frame_alloc();
        packet_ = av_packet_alloc();
        if (!frame_ || !packet_) {
            close();
            return false;
        }

        path_ = path;
        return true;
    }

    void close() override {
        if (sws_ctx_) { sws_freeContext(sws_ctx_); sws_ctx_ = nullptr; }
        if (frame_) { av_frame_free(&frame_); }
        if (packet_) { av_packet_free(&packet_); }
        if (codec_ctx_) { avcodec_free_context(&codec_ctx_); }
        if (fmt_ctx_) { avformat_close_input(&fmt_ctx_); }
        video_stream_idx_ = -1;
        path_.clear();
        info_ = {};
    }

    bool is_open() const override { return fmt_ctx_ != nullptr && codec_ctx_ != nullptr; }
    VideoStreamInfo info() const override { return info_; }

    GopostFrame* decode_frame_at(double source_time_seconds) override {
        if (!is_open() || !engine_) return nullptr;

        double clamped = source_time_seconds;
        if (clamped < 0) clamped = 0;
        if (info_.duration_seconds > 0 && clamped > info_.duration_seconds)
            clamped = info_.duration_seconds;

        AVStream* stream = fmt_ctx_->streams[video_stream_idx_];
        int64_t target_ts = (int64_t)(clamped / av_q2d(stream->time_base));

        avcodec_flush_buffers(codec_ctx_);
        if (av_seek_frame(fmt_ctx_, video_stream_idx_, target_ts,
                          AVSEEK_FLAG_BACKWARD) < 0) {
            av_seek_frame(fmt_ctx_, video_stream_idx_, 0, AVSEEK_FLAG_BACKWARD);
        }
        avcodec_flush_buffers(codec_ctx_);

        while (av_read_frame(fmt_ctx_, packet_) >= 0) {
            if (packet_->stream_index != video_stream_idx_) {
                av_packet_unref(packet_);
                continue;
            }

            int ret = avcodec_send_packet(codec_ctx_, packet_);
            av_packet_unref(packet_);
            if (ret < 0) continue;

            ret = avcodec_receive_frame(codec_ctx_, frame_);
            if (ret == AVERROR(EAGAIN)) continue;
            if (ret < 0) return nullptr;

            double frame_pts = 0;
            if (frame_->pts != AV_NOPTS_VALUE) {
                frame_pts = (double)frame_->pts * av_q2d(stream->time_base);
            }

            if (frame_pts < clamped - 1.0 / info_.frame_rate) {
                av_frame_unref(frame_);
                continue;
            }

            return convert_frame_to_rgba();
        }

        // Try flushing decoder for remaining frames
        avcodec_send_packet(codec_ctx_, nullptr);
        if (avcodec_receive_frame(codec_ctx_, frame_) == 0) {
            return convert_frame_to_rgba();
        }

        return nullptr;
    }

private:
    GopostFrame* convert_frame_to_rgba() {
        GopostFrame* out = nullptr;
        if (gopost_frame_acquire(engine_, &out,
                                 (uint32_t)frame_->width, (uint32_t)frame_->height,
                                 GOPOST_PIXEL_FORMAT_RGBA8) != GOPOST_OK) {
            av_frame_unref(frame_);
            return nullptr;
        }
        if (!out || !out->data) {
            av_frame_unref(frame_);
            return nullptr;
        }

        uint8_t* dst_data[1] = { out->data };
        int dst_linesize[1] = { (int)(out->width * 4) };

        sws_scale(sws_ctx_,
                  frame_->data, frame_->linesize,
                  0, frame_->height,
                  dst_data, dst_linesize);

        av_frame_unref(frame_);
        return out;
    }

    GopostEngine* engine_ = nullptr;
    std::string path_;
    VideoStreamInfo info_;

    AVFormatContext* fmt_ctx_ = nullptr;
    AVCodecContext* codec_ctx_ = nullptr;
    SwsContext* sws_ctx_ = nullptr;
    AVFrame* frame_ = nullptr;
    AVPacket* packet_ = nullptr;
    int video_stream_idx_ = -1;
};

std::unique_ptr<IVideoDecoder> create_video_decoder(GopostEngine* engine) {
    return std::make_unique<FFmpegVideoDecoder>(engine);
}

}  // namespace video
}  // namespace gopost
#endif
