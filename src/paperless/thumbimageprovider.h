#ifndef PAPERLESS_THUMBIMAGEPROVIDER_H
#define PAPERLESS_THUMBIMAGEPROVIDER_H

#include <QAtomicInt>
#include <QByteArray>
#include <QImage>
#include <QObject>
#include <QQuickImageProvider>
#include <QString>

class PaperlessApi;

// Asks the server for a thumbnail on the GUI thread, where the network stack
// and the credentials live, and hands the bytes on untouched. Everything that
// costs time is done elsewhere.
class ThumbnailFetcher : public QObject
{
    Q_OBJECT

public:
    explicit ThumbnailFetcher(PaperlessApi *api, QObject *parent = nullptr);

    QString cacheDir() const { return m_cacheDir; }

public slots:
    void fetch(int requestId, const QString &kind, int documentId);

signals:
    void fetched(int requestId, const QByteArray &data, const QString &error);

private:
    PaperlessApi *m_api;
    QString m_cacheDir;
};

// Lives on the thread the QML engine loads images on and does its work there:
// the cache file is read and written, and the image decoded, away from the GUI
// thread. The reply from the fetcher arrives as a posted event rather than as a
// call out of the GUI thread, so a response the engine has cancelled and
// deleted is never written into behind its back.
class ThumbnailResponse : public QQuickImageResponse
{
    Q_OBJECT

public:
    ThumbnailResponse(int requestId, const QString &kind, int documentId,
                      const QString &cacheDir, ThumbnailFetcher *fetcher);

    QQuickTextureFactory *textureFactory() const override;
    QString errorString() const override;

public slots:
    // Started by the provider once it has returned, so the engine is not kept
    // waiting on a cache file.
    void begin();
    void cancel() override;

private slots:
    void handleFetched(int requestId, const QByteArray &data, const QString &error);

private:
    QString cacheFilePath() const;
    void finish(const QImage &image, const QString &error);

    int m_requestId;
    QString m_kind;
    int m_documentId;
    QString m_cacheDir;
    ThumbnailFetcher *m_fetcher;
    QAtomicInt m_done;
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
