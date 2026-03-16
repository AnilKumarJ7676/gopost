#pragma once

#include <QString>
#include <QByteArray>
#include <QList>
#include <QHash>
#include <QDir>
#include <QMap>
#include <memory>
#include <optional>

#include "video_editor/domain/services/thumbnail_service.h"

namespace gopost::video_editor {

/// Thumbnail service backed by the native DecoderPool + ThumbnailGenerator.
///
/// Unlike ThumbnailService which spawns FFmpeg processes, this uses the
/// engine's DecoderPool to process videos sequentially -- one video at a
/// time -- preventing decoder resource exhaustion.
class NativeThumbnailService : public ThumbnailServiceInterface {
public:
    NativeThumbnailService(void* libHandle, void* enginePtr, int maxDecoders = 2);
    ~NativeThumbnailService();

    /// Whether the native decoder pool and thumbnail generator are ready.
    bool isInitialized() const { return initialized_; }

    /// Initialize the decoder pool and thumbnail generator.
    void initialize();

    /// Clean up native resources.
    void dispose();

    /// Change max concurrent decoders.
    void setMaxDecoders(int max);

    /// Flush idle decoders to free memory.
    void flushIdleDecoders();

    // ThumbnailServiceInterface
    QList<QByteArray> getCached(const QString& sourcePath, int count) override;

    QList<QByteArray> extractThumbnails(
        const QString& sourcePath,
        double sourceDuration,
        int count
    ) override;

    std::optional<QByteArray> extractSingleThumbnail(
        const QString& sourcePath,
        double timeSeconds = 0.5
    ) override;

    void clearCache() override;

private:
    void* libHandle_{nullptr};
    void* enginePtr_{nullptr};
    int maxDecoders_{2};

    void* poolPtr_{nullptr};
    void* genPtr_{nullptr};
    bool initialized_{false};

    // LRU cache
    static constexpr int kThumbWidth = 160;
    static constexpr int kThumbHeight = 90;
    static constexpr int kMaxCacheEntries = 200;

    QMap<QString, QList<QByteArray>> cache_;
    QMap<int, QString> jobToKey_;
    std::optional<QDir> thumbDir_;

    [[nodiscard]] QString cacheKey(const QString& path, int count) const;
    void promoteAndEvict(const QString& key);
    [[nodiscard]] QDir ensureThumbDir();
};

} // namespace gopost::video_editor
