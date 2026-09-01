#ifndef PAPERLESS_UPLOADQUEUE_H
#define PAPERLESS_UPLOADQUEUE_H

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>
#include <QVector>

class PaperlessApi;
class QTimer;

// Uploads files one after another and follows the consumer task that Paperless
// starts for each of them, until the document has been created.
class UploadQueue : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged)

public:
    enum Status {
        Waiting,
        Uploading,
        Processing,
        Completed,
        Failed
    };
    Q_ENUM(Status)

    enum Roles {
        FileNameRole = Qt::UserRole + 1,
        TitleRole,
        StatusRole,
        MessageRole,
        ProgressRole,
        DocumentIdRole
    };

    explicit UploadQueue(PaperlessApi *api, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeCount() const;

    // Set temporary for files the app created itself, such as camera captures;
    // they are removed once the server has accepted them.
    Q_INVOKABLE void enqueue(const QString &filePath, const QVariantMap &metadata,
                             bool temporary = false);
    Q_INVOKABLE void retry(int index);
    Q_INVOKABLE void remove(int index);
    Q_INVOKABLE void clearFinished();

signals:
    void countChanged();
    void activeCountChanged();
    void uploadCompleted(int documentId, const QString &fileName);
    void uploadFailed(const QString &fileName, const QString &error);

private:
    struct Entry {
        int id;
        QString filePath;
        QString fileName;
        QString taskId;
        QString message;
        QVariantMap metadata;
        Status status;
        qreal progress;
        int documentId;
        bool temporary;
    };

    void startNext();
    void upload(int index);
    void pollTasks();
    void finish(int index, Status status, const QString &message, int documentId);
    void update(int index, const QVector<int> &roles);
    // Rows can be removed while an upload is in flight, so callbacks refer to
    // entries by id rather than by row.
    int indexOfId(int id) const;

    PaperlessApi *m_api;
    QTimer *m_pollTimer;
    QVector<Entry> m_entries;
    int m_nextId;
    bool m_busy;
};

#endif // PAPERLESS_UPLOADQUEUE_H
