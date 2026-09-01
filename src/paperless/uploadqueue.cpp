#include "uploadqueue.h"

#include "api.h"

#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

namespace {

const int PollIntervalMs = 3000;

QString translated(const char *text)
{
    return QCoreApplication::translate("UploadQueue", text);
}

// Paperless answers with a bare array before API version 10 and with a
// paginated object from then on.
QJsonArray taskResults(const QJsonDocument &document)
{
    if (document.isArray())
        return document.array();
    return document.object().value(QStringLiteral("results")).toArray();
}

}

UploadQueue::UploadQueue(PaperlessApi *api, QObject *parent)
    : QAbstractListModel(parent)
    , m_api(api)
    , m_pollTimer(new QTimer(this))
    , m_nextId(1)
    , m_busy(false)
{
    m_pollTimer->setInterval(PollIntervalMs);
    connect(m_pollTimer, &QTimer::timeout, this, &UploadQueue::pollTasks);
}

int UploadQueue::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QHash<int, QByteArray> UploadQueue::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(FileNameRole, "fileName");
    roles.insert(TitleRole, "title");
    roles.insert(StatusRole, "status");
    roles.insert(MessageRole, "message");
    roles.insert(ProgressRole, "progress");
    roles.insert(DocumentIdRole, "documentId");
    return roles;
}

QVariant UploadQueue::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.count())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case FileNameRole:
        return entry.fileName;
    case TitleRole:
        return entry.metadata.value(QStringLiteral("title")).toString();
    case StatusRole:
        return entry.status;
    case MessageRole:
        return entry.message;
    case ProgressRole:
        return entry.progress;
    case DocumentIdRole:
        return entry.documentId;
    default:
        return QVariant();
    }
}

int UploadQueue::activeCount() const
{
    int count = 0;
    for (int i = 0; i < m_entries.count(); ++i) {
        const Status status = m_entries.at(i).status;
        if (status == Waiting || status == Uploading || status == Processing)
            ++count;
    }
    return count;
}

void UploadQueue::update(int index, const QVector<int> &roles)
{
    const QModelIndex modelIndex = this->index(index, 0);
    emit dataChanged(modelIndex, modelIndex, roles);
}

int UploadQueue::indexOfId(int id) const
{
    for (int i = 0; i < m_entries.count(); ++i) {
        if (m_entries.at(i).id == id)
            return i;
    }
    return -1;
}

void UploadQueue::enqueue(const QString &filePath, const QVariantMap &metadata, bool temporary)
{
    Entry entry;
    entry.id = m_nextId++;
    entry.filePath = filePath;
    entry.fileName = QFileInfo(filePath).fileName();
    entry.metadata = metadata;
    entry.status = Waiting;
    entry.progress = 0;
    entry.documentId = -1;
    entry.temporary = temporary;

    beginInsertRows(QModelIndex(), m_entries.count(), m_entries.count());
    m_entries.append(entry);
    endInsertRows();

    emit countChanged();
    emit activeCountChanged();
    startNext();
}

void UploadQueue::retry(int index)
{
    if (index < 0 || index >= m_entries.count() || m_entries.at(index).status != Failed)
        return;

    m_entries[index].status = Waiting;
    m_entries[index].message.clear();
    m_entries[index].progress = 0;
    update(index, QVector<int>() << StatusRole << MessageRole << ProgressRole);
    emit activeCountChanged();
    startNext();
}

void UploadQueue::remove(int index)
{
    if (index < 0 || index >= m_entries.count())
        return;

    const Status status = m_entries.at(index).status;
    if (status == Uploading)
        return;

    beginRemoveRows(QModelIndex(), index, index);
    m_entries.remove(index);
    endRemoveRows();

    emit countChanged();
    emit activeCountChanged();
}

void UploadQueue::clearFinished()
{
    for (int i = m_entries.count() - 1; i >= 0; --i) {
        if (m_entries.at(i).status == Completed || m_entries.at(i).status == Failed) {
            beginRemoveRows(QModelIndex(), i, i);
            m_entries.remove(i);
            endRemoveRows();
        }
    }

    emit countChanged();
}

void UploadQueue::startNext()
{
    if (m_busy)
        return;

    for (int i = 0; i < m_entries.count(); ++i) {
        if (m_entries.at(i).status == Waiting) {
            upload(i);
            return;
        }
    }
}

void UploadQueue::upload(int index)
{
    m_busy = true;
    m_entries[index].status = Uploading;
    update(index, QVector<int>() << StatusRole);

    const int id = m_entries.at(index).id;
    const QString filePath = m_entries.at(index).filePath;
    const QVariantMap metadata = m_entries.at(index).metadata;

    m_api->uploadDocument(filePath, metadata,
                          [this, id](const QByteArray &taskId, const QString &error) {
        m_busy = false;

        const int index = indexOfId(id);
        if (index < 0) {
            startNext();
            return;
        }

        if (!error.isEmpty()) {
            finish(index, Failed, error, -1);
            startNext();
            return;
        }

        m_entries[index].taskId = QString::fromUtf8(taskId);
        m_entries[index].status = Processing;
        m_entries[index].message = translated("Waiting for the server to process the file");
        update(index, QVector<int>() << StatusRole << MessageRole);

        if (!m_pollTimer->isActive())
            m_pollTimer->start();

        startNext();
    }, [this, id](qint64 sent, qint64 total) {
        const int index = indexOfId(id);
        if (index < 0 || total <= 0)
            return;

        m_entries[index].progress = qreal(sent) / qreal(total);
        update(index, QVector<int>() << ProgressRole);
    });
}

void UploadQueue::pollTasks()
{
    bool pending = false;

    for (int i = 0; i < m_entries.count(); ++i) {
        if (m_entries.at(i).status != Processing || m_entries.at(i).taskId.isEmpty())
            continue;

        pending = true;
        const QString taskId = m_entries.at(i).taskId;
        m_api->fetchTasks(taskId, [this, taskId](const QJsonDocument &document, const QString &error) {
            if (!error.isEmpty())
                return;

            const QJsonArray results = taskResults(document);
            if (results.isEmpty())
                return;

            const QJsonObject task = results.at(0).toObject();
            const QString status = task.value(QStringLiteral("status")).toString().toUpper();
            if (status != QLatin1String("SUCCESS") && status != QLatin1String("FAILURE"))
                return;

            for (int i = 0; i < m_entries.count(); ++i) {
                if (m_entries.at(i).taskId != taskId)
                    continue;

                const QString message = task.value(QStringLiteral("result")).toString();
                if (status == QLatin1String("SUCCESS")) {
                    const int documentId = task.value(QStringLiteral("related_document")).toInt(-1);
                    finish(i, Completed, message, documentId);
                } else {
                    finish(i, Failed, message.isEmpty() ? translated("The server could not process the file")
                                                        : message, -1);
                }
                break;
            }
        });
    }

    if (!pending)
        m_pollTimer->stop();
}

void UploadQueue::finish(int index, Status status, const QString &message, int documentId)
{
    Entry &entry = m_entries[index];
    entry.status = status;
    entry.message = message;
    entry.documentId = documentId;
    entry.progress = status == Completed ? 1 : entry.progress;
    update(index, QVector<int>() << StatusRole << MessageRole << ProgressRole << DocumentIdRole);
    emit activeCountChanged();

    if (status == Completed) {
        if (entry.temporary)
            QFile::remove(entry.filePath);
        emit uploadCompleted(documentId, entry.fileName);
    } else {
        emit uploadFailed(entry.fileName, message);
    }
}
