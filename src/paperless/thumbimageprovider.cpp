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

void ThumbnailFetcher::fetch(int requestId, const QString &kind, int documentId)
{
    // "original" is the download endpoint asked for the file as it was
    // uploaded, which is the only version of an image that decodes here.
    const bool original = kind == QLatin1String("original");
    const QString endpoint = original ? QStringLiteral("download") : kind;

    if (!m_api->isAuthenticated()) {
        emit fetched(requestId, QByteArray(),
                     QCoreApplication::translate("ThumbnailFetcher", "Not signed in"));
        return;
    }

    m_api->getData(m_api->documentFileUrl(documentId, endpoint, original),
                   [this, requestId](const QByteArray &data, const QString &error, int) {
        emit fetched(requestId, data, error);
    });
}

ThumbnailResponse::ThumbnailResponse(int requestId, const QString &kind, int documentId,
                                     const QString &cacheDir, ThumbnailFetcher *fetcher)
    : m_requestId(requestId)
    , m_kind(kind)
    , m_documentId(documentId)
    , m_cacheDir(cacheDir)
    , m_fetcher(fetcher)
    , m_done(0)
{
    // The fetcher is on the GUI thread and this response is not, so the default
    // connection queues the reply into this thread instead of running it out of
    // the GUI thread. If the engine deletes this response first, the event that
    // was on its way is dropped with it.
    connect(m_fetcher, &ThumbnailFetcher::fetched,
            this, &ThumbnailResponse::handleFetched);
}

QQuickTextureFactory *ThumbnailResponse::textureFactory() const
{
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

QString ThumbnailResponse::errorString() const
{
    return m_error;
}

QString ThumbnailResponse::cacheFilePath() const
{
    // A preview or an original is read once and is far too large to keep.
    if (m_kind != QLatin1String("thumb"))
        return QString();

    return QStringLiteral("%1/thumb-%2").arg(m_cacheDir).arg(m_documentId);
}

void ThumbnailResponse::begin()
{
    if (m_done.loadAcquire())
        return;

    const QString path = cacheFilePath();
    if (!path.isEmpty()) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly)) {
            QImage cached;
            if (cached.loadFromData(file.readAll())) {
                finish(cached, QString());
                return;
            }
        }
    }

    QMetaObject::invokeMethod(m_fetcher, "fetch", Qt::QueuedConnection,
                              Q_ARG(int, m_requestId),
                              Q_ARG(QString, m_kind),
                              Q_ARG(int, m_documentId));
}

void ThumbnailResponse::handleFetched(int requestId, const QByteArray &data, const QString &error)
{
    if (requestId != m_requestId || m_done.loadAcquire())
        return;

    if (!error.isEmpty()) {
        finish(QImage(), error);
        return;
    }

    QImage image;
    if (!image.loadFromData(data)) {
        finish(QImage(), QCoreApplication::translate("ThumbnailFetcher",
                                                     "Unsupported image format"));
        return;
    }

    // Kept as the server sent it: nothing is re-encoded, so the file stays the
    // size the server made it and the next read is a plain decode.
    const QString path = cacheFilePath();
    if (!path.isEmpty() && QDir().mkpath(m_cacheDir)) {
        QFile file(path);
        if (file.open(QIODevice::WriteOnly))
            file.write(data);
    }

    finish(image, QString());
}

void ThumbnailResponse::finish(const QImage &image, const QString &error)
{
    if (!m_done.testAndSetRelease(0, 1))
        return;

    m_image = image;
    m_error = error;
    emit finished();
}

void ThumbnailResponse::cancel()
{
    // The engine deletes a response once it says it has finished, so a
    // cancelled one has to say so too or it stays behind.
    finish(QImage(), QString());
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
    ThumbnailResponse *response = new ThumbnailResponse(requestId, kind, documentId,
                                                        m_fetcher->cacheDir(), m_fetcher);

    // The response belongs to this thread, and starts itself here once the
    // engine has the response in hand.
    QMetaObject::invokeMethod(response, "begin", Qt::QueuedConnection);

    return response;
}
