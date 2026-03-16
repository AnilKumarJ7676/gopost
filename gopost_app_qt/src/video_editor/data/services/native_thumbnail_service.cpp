#include "video_editor/data/services/native_thumbnail_service.h"

#include <QFile>
#include <QStandardPaths>
#include <QDebug>
#include <cmath>

namespace gopost::video_editor {

NativeThumbnailService::NativeThumbnailService(void* libHandle, void* enginePtr, int maxDecoders)
    : libHandle_(libHandle), enginePtr_(enginePtr), maxDecoders_(maxDecoders) {}

NativeThumbnailService::~NativeThumbnailService() {
    dispose();
}

void NativeThumbnailService::initialize() {
    if (initialized_) return;

    // TODO: Use native FFI bindings to create decoder pool and thumbnail generator.
    // This requires the native engine library to be loaded and the C API to be available.
    //
    // Pseudocode:
    //   poolPtr_ = gopost_decoder_pool_create(enginePtr_, maxDecoders_);
    //   genPtr_ = gopost_thumbnail_generator_create(poolPtr_, enginePtr_);
    //   initialized_ = (poolPtr_ != nullptr && genPtr_ != nullptr);
    //
    // For now, mark as not initialized to fall back to FFmpeg CLI thumbnails.
    initialized_ = false;

    if (!initialized_) {
        qDebug() << "[NativeThumbnails] Native decoder pool not available, requires engine integration";
    }
}

void NativeThumbnailService::dispose() {
    // TODO: Destroy native resources via C API.
    // gopost_thumbnail_generator_destroy(genPtr_);
    // gopost_decoder_pool_destroy(poolPtr_);
    genPtr_ = nullptr;
    poolPtr_ = nullptr;
    initialized_ = false;
}

void NativeThumbnailService::setMaxDecoders(int max) {
    Q_UNUSED(max)
    // TODO: gopost_decoder_pool_set_max(poolPtr_, max);
}

void NativeThumbnailService::flushIdleDecoders() {
    // TODO: gopost_decoder_pool_flush_idle(poolPtr_);
}

QString NativeThumbnailService::cacheKey(const QString& path, int count) const {
    return QStringLiteral("%1::%2").arg(path).arg(count);
}

void NativeThumbnailService::promoteAndEvict(const QString& key) {
    auto value = cache_.take(key);
    cache_.insert(key, value);
    while (cache_.size() > kMaxCacheEntries) {
        cache_.erase(cache_.begin());
    }
}

QDir NativeThumbnailService::ensureThumbDir() {
    if (thumbDir_.has_value()) return *thumbDir_;
    const auto tmp = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    thumbDir_ = QDir(QStringLiteral("%1/gopost_thumbs").arg(tmp));
    if (!thumbDir_->exists()) thumbDir_->mkpath(QStringLiteral("."));
    return *thumbDir_;
}

QList<QByteArray> NativeThumbnailService::getCached(const QString& sourcePath, int count) {
    const auto key = cacheKey(sourcePath, count);
    auto it = cache_.find(key);
    if (it != cache_.end()) {
        promoteAndEvict(key);
        return *it;
    }
    return {};
}

QList<QByteArray> NativeThumbnailService::extractThumbnails(
    const QString& sourcePath,
    double sourceDuration,
    int count)
{
    const auto key = cacheKey(sourcePath, count);
    if (cache_.contains(key)) return cache_[key];

    const auto dir = ensureThumbDir();
    const auto hash = qHash(sourcePath);

    // Check disk cache
    QList<QByteArray> thumbs;
    bool allCached = true;
    for (int i = 0; i < count; ++i) {
        QFile file(QStringLiteral("%1/t_%2_%3_%4.jpg")
            .arg(dir.path()).arg(hash).arg(count).arg(i));
        if (file.exists() && file.size() > 0 && file.open(QIODevice::ReadOnly)) {
            thumbs.append(file.readAll());
        } else {
            allCached = false;
            break;
        }
    }

    if (allCached && thumbs.size() == count) {
        cache_[key] = thumbs;
        promoteAndEvict(key);
        return thumbs;
    }

    // TODO: Use native generator if initialized_.
    // For now return empty -- the caller should fall back to FFmpeg-based thumbnails.
    qDebug() << "[NativeThumbnails] extractThumbnails: native extraction not yet integrated for"
             << sourcePath;
    Q_UNUSED(sourceDuration)
    return {};
}

std::optional<QByteArray> NativeThumbnailService::extractSingleThumbnail(
    const QString& sourcePath, double timeSeconds)
{
    const auto results = extractThumbnails(sourcePath, timeSeconds * 2.0, 1);
    if (!results.isEmpty()) return results.first();
    return std::nullopt;
}

void NativeThumbnailService::clearCache() {
    cache_.clear();
    // TODO: gopost_thumbnail_cancel_all(genPtr_);
}

} // namespace gopost::video_editor
