#include "lookupmodel.h"

#include "api.h"
#include "staleness.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStringList>
#include <QUrlQuery>

namespace {

const int PageSize = 200;

}

LookupModel::LookupModel(PaperlessApi *api, const QString &endpoint, QObject *parent)
    : QAbstractListModel(parent)
    , m_api(api)
    , m_endpoint(endpoint)
    , m_generation(0)
    , m_inboxTagId(-1)
    , m_inboxDocumentCount(0)
    , m_loading(false)
    , m_ready(false)
{
    connect(m_api, &PaperlessApi::authenticatedChanged, this, [this]() {
        if (m_api->isAuthenticated())
            reload();
        else
            setReady(false);
    });
}

int LookupModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QHash<int, QByteArray> LookupModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(ItemIdRole, "itemId");
    roles.insert(NameRole, "name");
    roles.insert(ColorRole, "color");
    roles.insert(TextColorRole, "textColor");
    roles.insert(DocumentCountRole, "documentCount");
    roles.insert(IsInboxTagRole, "isInboxTag");
    return roles;
}

QVariant LookupModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.count())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case ItemIdRole:
        return entry.id;
    case NameRole:
        return entry.name;
    case ColorRole:
        return entry.color;
    case TextColorRole:
        return entry.textColor;
    case DocumentCountRole:
        return entry.documentCount;
    case IsInboxTagRole:
        return entry.isInboxTag;
    default:
        return QVariant();
    }
}

int LookupModel::indexOfId(int id) const
{
    return m_indexById.value(id, -1);
}

QString LookupModel::nameFor(int id) const
{
    const int index = indexOfId(id);
    return index < 0 ? QString() : m_entries.at(index).name;
}

QString LookupModel::colorFor(int id) const
{
    const int index = indexOfId(id);
    return index < 0 ? QString() : m_entries.at(index).color;
}

QString LookupModel::textColorFor(int id) const
{
    const int index = indexOfId(id);
    return index < 0 ? QString() : m_entries.at(index).textColor;
}

QStringList LookupModel::namesFor(const QVariantList &ids) const
{
    QStringList names;
    for (int i = 0; i < ids.count(); ++i) {
        const QString name = nameFor(ids.at(i).toInt());
        if (!name.isEmpty())
            names.append(name);
    }
    return names;
}

void LookupModel::setLoading(bool loading)
{
    if (loading == m_loading)
        return;

    m_loading = loading;
    emit loadingChanged();
}

void LookupModel::setReady(bool ready)
{
    if (ready == m_ready)
        return;

    m_ready = ready;
    emit readyChanged();
}

void LookupModel::reload()
{
    ++m_generation;
    m_incoming.clear();
    fetchPage(1);
}

void LookupModel::reloadIfStale(int seconds)
{
    if (m_loading || !paperlessIsStale(m_loadedAt, seconds))
        return;

    reload();
}

void LookupModel::fetchPage(int page)
{
    if (!m_api->isAuthenticated())
        return;

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page"), QString::number(page));
    query.addQueryItem(QStringLiteral("page_size"), QString::number(PageSize));
    query.addQueryItem(QStringLiteral("ordering"), QStringLiteral("name"));

    const int generation = m_generation;
    setLoading(true);

    m_api->getJson(m_api->apiUrl(m_endpoint, query),
                   [this, generation, page](const QJsonDocument &document, const QString &error) {
        if (generation != m_generation)
            return;

        if (!error.isEmpty()) {
            setLoading(false);
            return;
        }

        const QJsonObject root = document.object();
        const QJsonArray results = root.value(QStringLiteral("results")).toArray();
        for (int i = 0; i < results.count(); ++i) {
            const QJsonObject object = results.at(i).toObject();

            Entry entry;
            entry.id = object.value(QStringLiteral("id")).toInt();
            entry.name = object.value(QStringLiteral("name")).toString();
            entry.color = object.value(QStringLiteral("color")).toString();
            if (entry.color.isEmpty())
                entry.color = object.value(QStringLiteral("colour")).toString();
            entry.textColor = object.value(QStringLiteral("text_color")).toString();
            entry.documentCount = object.value(QStringLiteral("document_count")).toInt();
            entry.isInboxTag = object.value(QStringLiteral("is_inbox_tag")).toBool();
            m_incoming.append(entry);
        }

        const bool hasMore = !root.value(QStringLiteral("next")).isNull()
                && !results.isEmpty()
                && m_incoming.count() < root.value(QStringLiteral("count")).toInt();
        if (hasMore) {
            fetchPage(page + 1);
            return;
        }

        setLoading(false);

        beginResetModel();
        m_entries = m_incoming;
        m_indexById.clear();
        int inboxTagId = -1;
        int inboxDocumentCount = 0;
        for (int i = 0; i < m_entries.count(); ++i) {
            m_indexById.insert(m_entries.at(i).id, i);
            if (m_entries.at(i).isInboxTag && inboxTagId < 0) {
                inboxTagId = m_entries.at(i).id;
                inboxDocumentCount = m_entries.at(i).documentCount;
            }
        }
        endResetModel();

        if (inboxTagId != m_inboxTagId) {
            m_inboxTagId = inboxTagId;
            emit inboxTagIdChanged();
        }

        if (inboxDocumentCount != m_inboxDocumentCount) {
            m_inboxDocumentCount = inboxDocumentCount;
            emit inboxDocumentCountChanged();
        }

        m_incoming.clear();
        m_loadedAt = QDateTime::currentDateTimeUtc();
        emit countChanged();
        setReady(true);
    });
}
