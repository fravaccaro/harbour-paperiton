#include "tasklistmodel.h"

#include "api.h"
#include "taskfields.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStringList>
#include <QVariantList>

namespace {

QJsonArray taskResults(const QJsonDocument &document)
{
    if (document.isArray())
        return document.array();
    return document.object().value(QStringLiteral("results")).toArray();
}

QString taskName(const QJsonObject &task)
{
    // API version 10 renamed the field and added a readable variant.
    const QStringList keys = QStringList()
            << QStringLiteral("task_type_display")
            << QStringLiteral("task_type")
            << QStringLiteral("task_name");
    for (int i = 0; i < keys.count(); ++i) {
        const QString value = task.value(keys.at(i)).toString();
        if (!value.isEmpty())
            return value;
    }
    return QString();
}

}

TaskListModel::TaskListModel(PaperlessApi *api, QObject *parent)
    : QAbstractListModel(parent)
    , m_api(api)
    , m_generation(0)
    , m_loading(false)
    , m_failedOnly(false)
{
}

int TaskListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QHash<int, QByteArray> TaskListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(TaskIdRole, "taskId");
    roles.insert(NameRole, "name");
    roles.insert(FileNameRole, "fileName");
    roles.insert(StatusRole, "status");
    roles.insert(ResultRole, "result");
    roles.insert(CreatedRole, "created");
    roles.insert(DocumentIdRole, "documentId");
    roles.insert(AcknowledgedRole, "acknowledged");
    return roles;
}

QVariant TaskListModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.count())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case TaskIdRole:
        return entry.taskId;
    case NameRole:
        return entry.name;
    case FileNameRole:
        return entry.fileName;
    case StatusRole:
        return entry.status;
    case ResultRole:
        return entry.result;
    case CreatedRole:
        return entry.created;
    case DocumentIdRole:
        return entry.documentId;
    case AcknowledgedRole:
        return entry.acknowledged;
    default:
        return QVariant();
    }
}

void TaskListModel::setLoading(bool loading)
{
    if (loading == m_loading)
        return;

    m_loading = loading;
    emit loadingChanged();
}

void TaskListModel::setErrorString(const QString &error)
{
    if (error == m_errorString)
        return;

    m_errorString = error;
    emit errorStringChanged();
}

void TaskListModel::setFailedOnly(bool failedOnly)
{
    if (failedOnly == m_failedOnly)
        return;

    m_failedOnly = failedOnly;
    emit failedOnlyChanged();
    reload();
}

void TaskListModel::reload()
{
    if (!m_api->isAuthenticated())
        return;

    ++m_generation;
    const int generation = m_generation;
    setLoading(true);

    m_api->fetchTasks(QString(), [this, generation](const QJsonDocument &document, const QString &error) {
        if (generation != m_generation)
            return;

        setLoading(false);

        if (!error.isEmpty()) {
            setErrorString(error);
            return;
        }

        setErrorString(QString());

        const QJsonArray results = taskResults(document);
        QVector<Entry> entries;
        for (int i = 0; i < results.count(); ++i) {
            const QJsonObject task = results.at(i).toObject();

            Entry entry;
            entry.id = task.value(QStringLiteral("id")).toInt();
            entry.taskId = task.value(QStringLiteral("task_id")).toString();
            entry.name = taskName(task);
            entry.fileName = paperlessTaskFileName(task);
            entry.status = task.value(QStringLiteral("status")).toString().toUpper();
            entry.result = paperlessTaskMessage(task);
            entry.created = QDateTime::fromString(task.value(QStringLiteral("date_created")).toString(),
                                                  Qt::ISODate);
            entry.documentId = paperlessTaskDocumentId(task);
            entry.acknowledged = task.value(QStringLiteral("acknowledged")).toBool();

            if (m_failedOnly && entry.status != QLatin1String("FAILURE"))
                continue;

            entries.append(entry);
        }

        beginResetModel();
        m_entries = entries;
        endResetModel();
        emit countChanged();
    });
}

void TaskListModel::acknowledge(int index)
{
    if (index < 0 || index >= m_entries.count())
        return;

    const QVariantList ids = QVariantList() << m_entries.at(index).id;
    m_api->acknowledgeTasks(ids, [this](const QJsonDocument &, const QString &error) {
        if (error.isEmpty())
            reload();
        else
            setErrorString(error);
    });
}
