#include "video_editor/presentation/notifiers/media_pool_notifier.h"

#include <QFileInfo>
#include <QUrl>
#include <QUuid>
#include <QVariantMap>
#include <algorithm>

namespace gopost::video_editor {

// ---------------------------------------------------------------------------
// Filtered assets
// ---------------------------------------------------------------------------

std::vector<const MediaAsset*> MediaPoolState::filteredAssets() const {
    std::vector<const MediaAsset*> result;
    for (const auto& a : assets) {
        // Bin filter
        if (activeBinId && a.binId != *activeBinId) continue;
        // Type filter
        if (filterType.has_value() && a.type != *filterType) continue;
        // Search
        if (!searchQuery.isEmpty() &&
            !a.fileName.contains(searchQuery, Qt::CaseInsensitive)) continue;
        result.push_back(&a);
    }

    // Sort
    auto cmp = [this](const MediaAsset* a, const MediaAsset* b) -> bool {
        int c = 0;
        switch (sortBy) {
        case MediaPoolSortBy::Name:     c = a->fileName.compare(b->fileName, Qt::CaseInsensitive); break;
        case MediaPoolSortBy::Date:     c = a->importedAt < b->importedAt ? -1 : (a->importedAt > b->importedAt ? 1 : 0); break;
        case MediaPoolSortBy::Type:     c = static_cast<int>(a->type) - static_cast<int>(b->type); break;
        case MediaPoolSortBy::Duration: c = a->durationSeconds < b->durationSeconds ? -1 : (a->durationSeconds > b->durationSeconds ? 1 : 0); break;
        case MediaPoolSortBy::Size:     c = a->fileSizeBytes < b->fileSizeBytes ? -1 : (a->fileSizeBytes > b->fileSizeBytes ? 1 : 0); break;
        }
        return sortAscending ? c < 0 : c > 0;
    };
    std::sort(result.begin(), result.end(), cmp);
    return result;
}

// ---------------------------------------------------------------------------

MediaPoolNotifier::MediaPoolNotifier(QObject* parent) : QObject(parent) {}
MediaPoolNotifier::~MediaPoolNotifier() = default;

QString MediaPoolNotifier::generateAssetId() const {
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

// ---------------------------------------------------------------------------
// Assets
// ---------------------------------------------------------------------------

void MediaPoolNotifier::importFile(const QString& path) {
    qDebug() << "[MediaPool] importFile:" << path;
    QFileInfo fi(path);
    MediaAsset asset;
    asset.id            = generateAssetId();
    asset.filePath      = path;
    asset.fileName      = fi.fileName();
    asset.fileSizeBytes = fi.size();
    asset.importedAt    = QDateTime::currentDateTime();
    asset.status        = fi.exists() ? MediaAssetStatus::Online : MediaAssetStatus::Offline;

    // Detect type by extension
    const auto ext = fi.suffix().toLower();
    static const QStringList videoExts = {
        QStringLiteral("mp4"), QStringLiteral("mov"), QStringLiteral("avi"),
        QStringLiteral("mkv"), QStringLiteral("webm"), QStringLiteral("m4v"),
        QStringLiteral("flv"), QStringLiteral("wmv"), QStringLiteral("3gp")
    };
    static const QStringList imageExts = {
        QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"),
        QStringLiteral("webp"), QStringLiteral("gif"), QStringLiteral("bmp"),
        QStringLiteral("heic"), QStringLiteral("heif"), QStringLiteral("tiff")
    };
    static const QStringList audioExts = {
        QStringLiteral("mp3"), QStringLiteral("aac"), QStringLiteral("wav"),
        QStringLiteral("m4a"), QStringLiteral("flac"), QStringLiteral("ogg"),
        QStringLiteral("wma"), QStringLiteral("opus"), QStringLiteral("aiff")
    };

    if (videoExts.contains(ext))       asset.type = MediaAssetType::Video;
    else if (imageExts.contains(ext))  asset.type = MediaAssetType::Image;
    else if (audioExts.contains(ext))  asset.type = MediaAssetType::Audio;
    else                               asset.type = MediaAssetType::Video; // default

    state_.assets.push_back(std::move(asset));
    emit stateChanged();
}

void MediaPoolNotifier::removeAsset(const QString& assetId) {
    auto& a = state_.assets;
    a.erase(std::remove_if(a.begin(), a.end(),
                            [&](const MediaAsset& m) { return m.id == assetId; }),
            a.end());
    emit stateChanged();
}

void MediaPoolNotifier::moveAssetToBin(const QString& assetId, const QString& binId) {
    for (auto& a : state_.assets) {
        if (a.id == assetId) { a.binId = binId; break; }
    }
    emit stateChanged();
}

void MediaPoolNotifier::relinkAsset(const QString& assetId, const QString& newPath) {
    for (auto& a : state_.assets) {
        if (a.id == assetId) {
            a.filePath = newPath;
            a.status   = QFileInfo::exists(newPath) ? MediaAssetStatus::Online
                                                     : MediaAssetStatus::Offline;
            break;
        }
    }
    emit stateChanged();
}

void MediaPoolNotifier::checkAllAssetsOnline() {
    for (auto& a : state_.assets)
        a.status = a.checkOnline() ? MediaAssetStatus::Online : MediaAssetStatus::Offline;
    emit stateChanged();
}

// ---------------------------------------------------------------------------
// Bins
// ---------------------------------------------------------------------------

void MediaPoolNotifier::createBin(const QString& name) {
    MediaBin bin;
    bin.id   = generateAssetId();
    bin.name = name;
    state_.bins.push_back(std::move(bin));
    emit stateChanged();
}

void MediaPoolNotifier::renameBin(const QString& binId, const QString& name) {
    for (auto& b : state_.bins)
        if (b.id == binId) { b.name = name; break; }
    emit stateChanged();
}

void MediaPoolNotifier::removeBin(const QString& binId) {
    auto& b = state_.bins;
    b.erase(std::remove_if(b.begin(), b.end(),
                            [&](const MediaBin& m) { return m.id == binId; }),
            b.end());
    if (state_.activeBinId == binId)
        state_.activeBinId.reset();
    emit stateChanged();
}

void MediaPoolNotifier::setActiveBin(const QString& binId) {
    state_.activeBinId = binId.isEmpty() ? std::nullopt : std::optional(binId);
    emit stateChanged();
}

// ---------------------------------------------------------------------------
// QML property helpers
// ---------------------------------------------------------------------------

QVariantList MediaPoolNotifier::filteredAssetsVariant() const {
    QVariantList result;
    auto filtered = state_.filteredAssets();
    for (const auto* asset : filtered) {
        QVariantMap m;
        m[QStringLiteral("id")] = asset->id;
        m[QStringLiteral("displayName")] = asset->fileName;
        m[QStringLiteral("filePath")] = asset->filePath;
        m[QStringLiteral("mediaType")] = [&] {
            switch (asset->type) {
            case MediaAssetType::Video: return QStringLiteral("video");
            case MediaAssetType::Image: return QStringLiteral("image");
            case MediaAssetType::Audio: return QStringLiteral("audio");
            default:                    return QStringLiteral("video");
            }
        }();
        m[QStringLiteral("duration")] = asset->durationSeconds;
        m[QStringLiteral("fileSize")] = static_cast<qint64>(asset->fileSizeBytes);
        m[QStringLiteral("isSelected")] = (selectedAssetId_ == asset->id);
        result.append(m);
    }
    return result;
}

QString MediaPoolNotifier::currentFilter() const {
    if (!state_.filterType.has_value()) return QStringLiteral("all");
    switch (*state_.filterType) {
    case MediaAssetType::Video: return QStringLiteral("video");
    case MediaAssetType::Image: return QStringLiteral("image");
    case MediaAssetType::Audio: return QStringLiteral("audio");
    default:                    return QStringLiteral("all");
    }
}

void MediaPoolNotifier::selectAsset(const QString& assetId) {
    selectedAssetId_ = assetId;
    emit stateChanged();
}

void MediaPoolNotifier::addToTimeline(const QString& assetId) {
    qDebug() << "[MediaPool] addToTimeline called with id:" << assetId
             << "total assets:" << state_.assets.size();
    for (const auto& a : state_.assets) {
        if (a.id == assetId) {
            QString mediaType;
            switch (a.type) {
            case MediaAssetType::Video: mediaType = QStringLiteral("video"); break;
            case MediaAssetType::Image: mediaType = QStringLiteral("image"); break;
            case MediaAssetType::Audio: mediaType = QStringLiteral("audio"); break;
            default: mediaType = QStringLiteral("video"); break;
            }
            qDebug() << "[MediaPool] emitting addToTimelineRequested:"
                     << a.filePath << mediaType << a.fileName << a.durationSeconds;
            emit addToTimelineRequested(assetId, a.filePath, mediaType,
                                        a.fileName, a.durationSeconds);
            return;
        }
    }
    qWarning() << "[MediaPool] addToTimeline: asset NOT FOUND for id:" << assetId;
}

void MediaPoolNotifier::showFilePicker() {
    emit filePickerRequested();
}

void MediaPoolNotifier::importFiles(const QVariantList& urls) {
    for (const auto& urlVar : urls) {
        // Qt6 QML may double-wrap QUrl inside QVariant(QVariant(QUrl)).
        // Unwrap until we get a usable type.
        QVariant v = urlVar;
        while (v.typeId() == QMetaType::QVariant)
            v = v.value<QVariant>();

        QString path;
        if (v.canConvert<QUrl>()) {
            path = v.toUrl().toLocalFile();
        } else {
            path = v.toString();
            if (path.startsWith(QStringLiteral("file:///")))
                path = QUrl(path).toLocalFile();
            else if (path.startsWith(QStringLiteral("file://")))
                path = QUrl(path).toLocalFile();
        }
        qDebug() << "[MediaPool] importFiles resolved:" << path;
        if (!path.isEmpty())
            importFile(path);
    }
}

void MediaPoolNotifier::setFilter(const QString& filter) {
    if (filter == QStringLiteral("all") || filter.isEmpty()) {
        clearFilterType();
    } else if (filter == QStringLiteral("video")) {
        setFilterType(static_cast<int>(MediaAssetType::Video));
    } else if (filter == QStringLiteral("image")) {
        setFilterType(static_cast<int>(MediaAssetType::Image));
    } else if (filter == QStringLiteral("audio")) {
        setFilterType(static_cast<int>(MediaAssetType::Audio));
    }
}

void MediaPoolNotifier::cycleSort() {
    int current = static_cast<int>(state_.sortBy);
    int next = (current + 1) % 5; // 5 sort modes
    state_.sortBy = static_cast<MediaPoolSortBy>(next);
    emit stateChanged();
}

// ---------------------------------------------------------------------------
// Search / filter / sort
// ---------------------------------------------------------------------------

void MediaPoolNotifier::setSearchQuery(const QString& query) {
    state_.searchQuery = query;
    emit stateChanged();
}

void MediaPoolNotifier::setFilterType(int type) {
    state_.filterType = static_cast<MediaAssetType>(type);
    emit stateChanged();
}

void MediaPoolNotifier::clearFilterType() {
    state_.filterType.reset();
    emit stateChanged();
}

void MediaPoolNotifier::setSortBy(int sortBy) {
    state_.sortBy = static_cast<MediaPoolSortBy>(sortBy);
    emit stateChanged();
}

void MediaPoolNotifier::toggleSortOrder() {
    state_.sortAscending = !state_.sortAscending;
    emit stateChanged();
}

void MediaPoolNotifier::setViewMode(int mode) {
    state_.viewMode = static_cast<MediaPoolViewMode>(mode);
    emit stateChanged();
}

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------

void MediaPoolNotifier::loadFromData(const QVariantList& data) {
    Q_UNUSED(data);
    // TODO: Deserialise from QVariantList
}

QVariantList MediaPoolNotifier::toData() const {
    QVariantList result;
    // TODO: Serialise to QVariantList
    return result;
}

} // namespace gopost::video_editor
