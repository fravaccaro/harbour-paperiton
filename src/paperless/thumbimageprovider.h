#ifndef PAPERLESS_THUMBIMAGEPROVIDER_H
#define PAPERLESS_THUMBIMAGEPROVIDER_H

#include <QAtomicInt>
#include <QImage>
#include <QObject>
#include <QQuickImageProvider>
#include <QString>

class PaperlessApi;

// Downloads thumbnails and previews on the GUI thread, where the network
// stack and the credentials live, and hands the decoded image back to the
// QML image loading thread.
class ThumbnailFetcher : public QObject
{
    Q_OBJECT

public:
    explicit ThumbnailFetcher(PaperlessApi *api, QObject *parent = nullptr);

public slots:
    void fetch(int requestId, const QString &kind, int documentId);

signals:
    void fetched(int requestId, const QImage &image, const QString &error);

private:
    QString cacheFilePath(const QString &kind, int documentId) const;

    PaperlessApi *m_api;
    QString m_cacheDir;
};

class ThumbnailResponse : public QQuickImageResponse
{
    Q_OBJECT

public:
    explicit ThumbnailResponse(int requestId);

    QQuickTextureFactory *textureFactory() const override;
    QString errorString() const override;

public slots:
    void handleFetched(int requestId, const QImage &image, const QString &error);

private:
    int m_requestId;
    QImage m_image;
    QString m_error;
};

class ThumbImageProvider : public QQuickAsyncImageProvider
{
public:
    explicit ThumbImageProvider(ThumbnailFetcher *fetcher);

    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

private:
    ThumbnailFetcher *m_fetcher;
    QAtomicInt m_nextRequestId;
};

#endif // PAPERLESS_THUMBIMAGEPROVIDER_H
