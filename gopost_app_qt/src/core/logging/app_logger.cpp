#include "core/logging/app_logger.h"

#include <QDateTime>
#include <QLoggingCategory>

namespace gopost::core {

bool AppLogger::s_initialized = false;
CrashReportCallback AppLogger::onCrashReport = nullptr;

void AppLogger::init() {
    if (s_initialized) return;
    s_initialized = true;
    // Configure Qt logging categories/format as needed
    qSetMessagePattern(QStringLiteral("[%{time hh:mm:ss.zzz}] [%{type}] %{message}"));
}

void AppLogger::debug(const QString& message) {
    qDebug().noquote() << message;
}

void AppLogger::info(const QString& message) {
    qInfo().noquote() << message;
}

void AppLogger::warning(const QString& message) {
    qWarning().noquote() << message;
}

void AppLogger::error(const QString& message,
                      const QString& error,
                      const QString& stackTrace) {
    qCritical().noquote() << message;
    if (!error.isEmpty())
        qCritical().noquote() << QStringLiteral("  Error: ") << error;
    reportCrash(error.isEmpty() ? message : error, stackTrace);
}

void AppLogger::fatal(const QString& error, const QString& stackTrace) {
    qCritical().noquote() << QStringLiteral("FATAL: ") << error;
    reportCrash(error, stackTrace, true);
}

void AppLogger::reportCrash(const QString& error,
                             const QString& stackTrace,
                             bool fatal) {
    if (!onCrashReport) return;
    try {
        QVariantMap extra;
        extra[QStringLiteral("fatal")] = fatal;
        onCrashReport(error, stackTrace, extra);
    } catch (...) {
#ifdef QT_DEBUG
        throw;
#endif
    }
}

} // namespace gopost::core
