#include "documentlistmodel.h"

#include "api.h"

#include <QDate>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrlQuery>

namespace {

const int PageSize = 25;

QDateTime parseTimestamp(const QJsonValue &value)
{
    const QString text = value.toString();
    if (text.isEmpty())
        return QDateTime();

    const QDateTime dateTime = QDateTime::fromString(text, Qt::ISODate);
    if (dateTime.isValid())
        return dateTime;

    // API v9 turned "created" into a plain date.
    const QDate date = QDate::fromString(text.left(10), Qt::ISODate);
    return date.isValid() ? QDateTime(date) : QDateTime();
}

int optionalId(const QJsonValue &value)
{
    return value.isDouble() ? value.toInt() : -1;
}

}

PaperlessApi *DocumentListModel::s_api = nullptr;

void DocumentListModel::setApi(PaperlessApi *api)
{
    s_api = api;
}

DocumentListModel::DocumentListModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_ordering(QStringLiteral("-created"))
    , m_tagId(-1)
    , m_correspondentId(-1)
    , m_totalCount(0)
    , m_page(0)
    , m_generation(0)
    , m_loading(false)
{
}

int DocumentListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QHash<int, QByteArray> DocumentListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(DocumentIdRole, "documentId");
    roles.insert(TitleRole, "title");
    roles.insert(CreatedRole, "created");
    roles.insert(AddedRole, "added");
    roles.insert(CorrespondentIdRole, "correspondentId");
    roles.insert(DocumentTypeIdRole, "documentTypeId");
    roles.insert(TagIdsRole, "tagIds");
    roles.insert(ThumbnailSourceRole, "thumbnailSource");
    roles.insert(OriginalFileNameRole, "originalFileName");
    roles.insert(ArchiveSerialNumberRole, "archiveSerialNumber");
    roles.insert(PageCountRole, "pageCount");
    return roles;
}

QVariant DocumentListModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.count())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case DocumentIdRole:
        return entry.id;
    case TitleRole:
        return entry.title;
    case CreatedRole:
        return entry.created;
    case AddedRole:
        return entry.added;
    case CorrespondentIdRole:
        return entry.correspondentId;
    case DocumentTypeIdRole:
        return entry.documentTypeId;
    case TagIdsRole:
        return entry.tagIds;
    case ThumbnailSourceRole:
        return QStringLiteral("image://paperless/thumb/%1").arg(entry.id);
    case OriginalFileNameRole:
        return entry.originalFileName;
    case ArchiveSerialNumberRole:
        return entry.archiveSerialNumber;
    case PageCountRole:
        return entry.pageCount;
    default:
        return QVariant();
    }
}

QVariantMap DocumentListModel::get(int index) const
{
    QVariantMap map;
    if (index < 0 || index >= m_entries.count())
        return map;

    const QHash<int, QByteArray> roles = roleNames();
    for (QHash<int, QByteArray>::const_iterator it = roles.constBegin(); it != roles.constEnd(); ++it)
        map.insert(QString::fromUtf8(it.value()), data(this->index(index, 0), it.key()));
    return map;
}

bool DocumentListModel::hasFilters() const
{
    return !m_searchQuery.isEmpty() || m_tagId > 0 || m_correspondentId > 0 || !m_filters.isEmpty();
}

bool DocumentListModel::canLoadMore() const
{
    return !m_loading && m_entries.count() < m_totalCount;
}

void DocumentListModel::setLoading(bool loading)
{
    if (loading == m_loading)
        return;

    m_loading = loading;
    emit loadingChanged();
    emit canLoadMoreChanged();
}

void DocumentListModel::setErrorString(const QString &error)
{
    if (error == m_errorString)
        return;

    m_errorString = error;
    emit errorStringChanged();
}

void DocumentListModel::setSearchQuery(const QString &query)
{
    if (query == m_searchQuery)
        return;

    m_searchQuery = query;
    emit searchQueryChanged();
    reload();
}

void DocumentListModel::setTagId(int id)
{
    if (id == m_tagId)
        return;

    m_tagId = id;
    emit tagIdChanged();
    reload();
}

void DocumentListModel::setCorrespondentId(int id)
{
    if (id == m_correspondentId)
        return;

    m_correspondentId = id;
    emit correspondentIdChanged();
    reload();
}

void DocumentListModel::setOrdering(const QString &ordering)
{
    if (ordering == m_ordering)
        return;

    m_ordering = ordering;
    emit orderingChanged();
    reload();
}

void DocumentListModel::setFilters(const QVariantMap &filters)
{
    if (filters == m_filters)
        return;

    m_filters = filters;
    emit filtersChanged();
    reload();
}

void DocumentListModel::clearFilters()
{
    if (m_tagId == -1 && m_correspondentId == -1 && m_searchQuery.isEmpty() && m_filters.isEmpty())
        return;

    m_tagId = -1;
    m_correspondentId = -1;
    m_searchQuery.clear();
    m_filters.clear();
    emit tagIdChanged();
    emit correspondentIdChanged();
    emit searchQueryChanged();
    emit filtersChanged();
    reload();
}

void DocumentListModel::reload()
{
    // Invalidates replies of the previous query.
    ++m_generation;

    if (!m_entries.isEmpty()) {
        beginResetModel();
        m_entries.clear();
        endResetModel();
        emit countChanged();
    }

    m_page = 0;
    if (m_totalCount != 0) {
        m_totalCount = 0;
        emit totalCountChanged();
    }

    setErrorString(QString());
    fetchPage(1);
}

void DocumentListModel::loadMore()
{
    if (!canLoadMore())
        return;

    fetchPage(m_page + 1);
}

void DocumentListModel::fetchPage(int page)
{
    if (!s_api || !s_api->isAuthenticated()) {
        setLoading(false);
        return;
    }

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page"), QString::number(page));
    query.addQueryItem(QStringLiteral("page_size"), QString::number(PageSize));
    query.addQueryItem(QStringLiteral("ordering"), m_ordering);
    if (!m_searchQuery.isEmpty())
        query.addQueryItem(QStringLiteral("query"), m_searchQuery);
    if (m_tagId > 0)
        query.addQueryItem(QStringLiteral("tags__id__all"), QString::number(m_tagId));
    if (m_correspondentId > 0)
        query.addQueryItem(QStringLiteral("correspondent__id"), QString::number(m_correspondentId));
    for (QVariantMap::const_iterator it = m_filters.constBegin(); it != m_filters.constEnd(); ++it)
        query.addQueryItem(it.key(), it.value().toString());

    const int generation = m_generation;
    setLoading(true);

    s_api->getJson(s_api->apiUrl(QStringLiteral("documents"), query),
                   [this, generation, page](const QJsonDocument &document, const QString &error) {
        if (generation != m_generation)
            return;

        setLoading(false);

        if (!error.isEmpty()) {
            setErrorString(error);
            return;
        }

        setErrorString(QString());

        const QJsonObject root = document.object();
        const int total = root.value(QStringLiteral("count")).toInt();
        if (total != m_totalCount) {
            m_totalCount = total;
            emit totalCountChanged();
        }
        if (!hasFilters())
            s_api->setTotalDocuments(total);

        const QJsonArray results = root.value(QStringLiteral("results")).toArray();
        QVector<Entry> entries;
        entries.reserve(results.count());
        for (int i = 0; i < results.count(); ++i) {
            const QJsonObject object = results.at(i).toObject();

            Entry entry;
            entry.id = object.value(QStringLiteral("id")).toInt();
            entry.title = object.value(QStringLiteral("title")).toString();
            entry.created = parseTimestamp(object.value(QStringLiteral("created")));
            entry.added = parseTimestamp(object.value(QStringLiteral("added")));
            entry.correspondentId = optionalId(object.value(QStringLiteral("correspondent")));
            entry.documentTypeId = optionalId(object.value(QStringLiteral("document_type")));
            entry.originalFileName = object.value(QStringLiteral("original_file_name")).toString();
            entry.pageCount = object.value(QStringLiteral("page_count")).toInt();

            const QJsonValue asn = object.value(QStringLiteral("archive_serial_number"));
            entry.archiveSerialNumber = asn.isDouble() ? QVariant(asn.toInt()) : QVariant();

            const QJsonArray tags = object.value(QStringLiteral("tags")).toArray();
            for (int t = 0; t < tags.count(); ++t)
                entry.tagIds.append(tags.at(t).toInt());

            entries.append(entry);
        }

        if (!entries.isEmpty()) {
            beginInsertRows(QModelIndex(), m_entries.count(), m_entries.count() + entries.count() - 1);
            m_entries += entries;
            endInsertRows();
            emit countChanged();
        }

        m_page = page;
        emit canLoadMoreChanged();
    });
}
