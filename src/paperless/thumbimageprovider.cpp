#include "thumbimageprovider.h"

#include "api.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QQuickTextureFactory>
#include <QStandardPaths>

ThumbnailFetcher::ThumbnailFetcher(PaperlessApi *api, QObject *parent)
    : QObject(parent)
    , m_api(api)
    , m_cacheDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                 + QStringLiteral("/thumbnails"))
{
}

QString ThumbnailFetcher::cacheFilePath(const QString &kind, int documentId) const
{
    return QStringLiteral("%1/%2-%3.png").arg(m_cacheDir, kind).arg(documentId);
}

void ThumbnailFetcher::fetch(int requestId, const QString &kind, int documentId)
{
    const bool cacheable = kind == QLatin1String("thumb");
    const QString cachePath = cacheFilePath(kind, documentId);

    if (cacheable && QFile::exists(cachePath)) {
        QImage cached;
        if (cached.load(cachePath)) {
            emit fetched(requestId, cached, QString());
            return;
        }
    }

    if (!m_api->isAuthenticated()) {
        emit fetched(requestId, QImage(),
                     QCoreApplication::translate("ThumbnailFetcher", "Not signed in"));
        return;
    }

    m_api->getData(m_api->documentFileUrl(documentId, kind),
                   [this, requestId, cacheable, cachePath](const QByteArray &data, const QString &error) {
        if (!error.isEmpty()) {
            emit fetched(requestId, QImage(), error);
            return;
        }

        QImage image;
        if (!image.loadFromData(data)) {
            emit fetched(requestId, QImage(),
                         QCoreApplication::translate("ThumbnailFetcher", "Unsupported image format"));
            return;
        }

        if (cacheable && QDir().mkpath(m_cacheDir))
            image.save(cachePath, "PNG");

        emit fetched(requestId, image, QString());
    });
}

ThumbnailResponse::ThumbnailResponse(int requestId)
    : m_requestId(requestId)
{
}

QQuickTextureFactory *ThumbnailResponse::textureFactory() const
{
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

QString ThumbnailResponse::errorString() const
{
    return m_error;
}

void ThumbnailResponse::handleFetched(int requestId, const QImage &image, const QString &error)
{
    if (requestId != m_requestId)
        return;

    m_image = image;
    m_error = error;
    emit finished();
}

ThumbImageProvider::ThumbImageProvider(ThumbnailFetcher *fetcher)
    : m_fetcher(fetcher)
    , m_nextRequestId(1)
{
}

QQuickImageResponse *ThumbImageProvider::requestImageResponse(const QString &id, const QSize &)
{
    const int separator = id.indexOf(QLatin1Char('/'));
    const QString kind = separator < 0 ? QStringLiteral("thumb") : id.left(separator);
    const int documentId = id.mid(separator + 1).toInt();

    const int requestId = m_nextRequestId.fetchAndAddOrdered(1);
    ThumbnailResponse *response = new ThumbnailResponse(requestId);

    // Direct connection: the fetcher runs on the GUI thread and the response
    // may signal completion from any thread.
    QObject::connect(m_fetcher, &ThumbnailFetcher::fetched,
                     response, &ThumbnailResponse::handleFetched, Qt::DirectConnection);

    QMetaObject::invokeMethod(m_fetcher, "fetch", Qt::QueuedConnection,
                              Q_ARG(int, requestId),
                              Q_ARG(QString, kind),
                              Q_ARG(int, documentId));

    return response;
}
