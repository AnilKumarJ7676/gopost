#if defined(__APPLE__)
#include "decoder_interface.hpp"
#include "gopost/engine.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

namespace gopost {
namespace video {

class AVFoundationVideoDecoder : public IVideoDecoder {
public:
    explicit AVFoundationVideoDecoder(GopostEngine* engine) : engine_(engine) {}

    ~AVFoundationVideoDecoder() override { close(); }

    bool open(const std::string& path) override {
        @autoreleasepool {
            close();
            if (path.empty() || !engine_) return false;

            NSURL* url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]];
            asset_ = [AVURLAsset URLAssetWithURL:url options:nil];
            if (!asset_) return false;

            NSArray<AVAssetTrack*>* tracks = [asset_ tracksWithMediaType:AVMediaTypeVideo];
            if (tracks.count == 0) return false;

            AVAssetTrack* vt = tracks[0];
            CGSize size = vt.naturalSize;
            CGAffineTransform transform = vt.preferredTransform;

            if (transform.b == 1.0 && transform.c == -1.0) {
                info_.width = (int32_t)size.height;
                info_.height = (int32_t)size.width;
            } else if (transform.b == -1.0 && transform.c == 1.0) {
                info_.width = (int32_t)size.height;
                info_.height = (int32_t)size.width;
            } else {
                info_.width = (int32_t)size.width;
                info_.height = (int32_t)size.height;
            }

            info_.frame_rate = vt.nominalFrameRate;
            if (info_.frame_rate <= 0) info_.frame_rate = 30.0;
            info_.duration_seconds = CMTimeGetSeconds(asset_.duration);
            info_.frame_count = (int64_t)(info_.duration_seconds * info_.frame_rate);

            imageGen_ = [[AVAssetImageGenerator alloc] initWithAsset:asset_];
            imageGen_.appliesPreferredTrackTransform = YES;
            imageGen_.requestedTimeToleranceBefore = CMTimeMake(1, 600);
            imageGen_.requestedTimeToleranceAfter = CMTimeMake(1, 600);
            imageGen_.maximumSize = CGSizeMake(info_.width, info_.height);

            path_ = path;
            return true;
        }
    }

    void close() override {
        @autoreleasepool {
            imageGen_ = nil;
            asset_ = nil;
            path_.clear();
            info_ = {};
        }
    }

    bool is_open() const override { return !path_.empty() && asset_ != nil; }
    VideoStreamInfo info() const override { return info_; }

    GopostFrame* decode_frame_at(double source_time_seconds) override {
        @autoreleasepool {
            if (!is_open() || !engine_) return nullptr;

            double clamped = source_time_seconds;
            if (clamped < 0) clamped = 0;
            if (clamped > info_.duration_seconds) clamped = info_.duration_seconds;

            CMTime requestTime = CMTimeMakeWithSeconds(clamped, 600);
            CMTime actualTime;
            NSError* error = nil;

            CGImageRef cgImage = [imageGen_ copyCGImageAtTime:requestTime
                                                   actualTime:&actualTime
                                                        error:&error];
            if (!cgImage) return nullptr;

            size_t w = CGImageGetWidth(cgImage);
            size_t h = CGImageGetHeight(cgImage);

            GopostFrame* frame = nullptr;
            if (gopost_frame_acquire(engine_, &frame, (uint32_t)w, (uint32_t)h,
                                     GOPOST_PIXEL_FORMAT_RGBA8) != GOPOST_OK) {
                CGImageRelease(cgImage);
                return nullptr;
            }
            if (!frame || !frame->data) {
                CGImageRelease(cgImage);
                return nullptr;
            }

            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGContextRef ctx = CGBitmapContextCreate(
                frame->data, w, h, 8, w * 4, colorSpace,
                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

            if (ctx) {
                CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cgImage);
                CGContextRelease(ctx);
            }
            CGColorSpaceRelease(colorSpace);
            CGImageRelease(cgImage);
            return frame;
        }
    }

private:
    GopostEngine* engine_ = nullptr;
    std::string path_;
    VideoStreamInfo info_;
    AVURLAsset* __strong asset_ = nil;
    AVAssetImageGenerator* __strong imageGen_ = nil;
};

std::unique_ptr<IVideoDecoder> create_video_decoder(GopostEngine* engine) {
    return std::make_unique<AVFoundationVideoDecoder>(engine);
}

}  // namespace video
}  // namespace gopost
#endif
