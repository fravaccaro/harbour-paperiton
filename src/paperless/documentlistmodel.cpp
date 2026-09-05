#include "documentlistmodel.h"

#include "api.h"
#include "staleness.h"

#include <QDate>
#include <QJsonArray>
#include <QJsonObject>
#include <QSet>
#include <QUrlQuery>

namespace {

// One request brings back this many documents, and the page a request asks for
// is worked out from how many documents the list already holds, so the two must
// never disagree.
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

// The server sorts documents by a plain date, so documents of the same day have
// no fixed order, and a page is a slice of that order: between two requests a
// document can move across a page boundary, appear twice and push another out
// of the list entirely. The id settles every tie.
QString orderingWithTiebreak(const QString &ordering)
{
    if (ordering.isEmpty() || ordering == QStringLiteral("id")
            || ordering == QStringLiteral("-id")) {
        return ordering;
    }

    return ordering + (ordering.startsWith(QLatin1Char('-')) ? QStringLiteral(",-id")
                                                             : QStringLiteral(",id"));
}

}

bool DocumentListModel::Entry::operator==(const Entry &other) const
{
    return id == other.id
            && title == other.title
            && created == other.created
            && added == other.added
            && correspondentId == other.correspondentId
            && documentTypeId == other.documentTypeId
            && tagIds == other.tagIds
            && originalFileName == other.originalFileName
            && archiveSerialNumber == other.archiveSerialNumber
            && pageCount == other.pageCount;
}

DocumentListModel::DocumentListModel(PaperlessApi *api, QObject *parent)
    : QAbstractListModel(parent)
    , m_api(api)
    , m_ordering(defaultOrdering())
    , m_tagId(-1)
    , m_correspondentId(-1)
    , m_totalCount(0)
    , m_expectedRows(0)
    , m_generation(0)
    , m_request(NoRequest)
    , m_endReached(false)
    , m_searchRejected(false)
{
    // The list belongs to a server and an account: signing out has to leave
    // nothing of the previous one behind, and signing in starts a fresh list.
    connect(m_api, &PaperlessApi::authenticatedChanged, this, [this]() {
        if (m_api->isAuthenticated())
            reload();
        else
            clear();
    });

    // A document deleted from anywhere in the app leaves the list, so no page
    // has to remember to ask for one.
    connect(m_api, &PaperlessApi::documentDeleted, this, &DocumentListModel::removeDocument);
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
    return m_request == NoRequest && !m_endReached && m_entries.count() < m_totalCount;
}

void DocumentListModel::setRequest(Request request)
{
    if (request == m_request)
        return;

    m_request = request;
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

void DocumentListModel::setSearchRejected(bool rejected)
{
    if (rejected == m_searchRejected)
        return;

    m_searchRejected = rejected;
    emit searchRejectedChanged();
}

void DocumentListModel::reportError(const QString &error)
{
    setErrorString(error);

    // An empty list shows the reason in place of the documents; a list that
    // still holds documents keeps them, and says what went wrong instead.
    if (!m_entries.isEmpty())
        emit loadFailed(error);
}

bool DocumentListModel::changeSearchQuery(const QString &query)
{
    if (query == m_searchQuery)
        return false;

    m_searchQuery = query;
    emit searchQueryChanged();
    return true;
}

bool DocumentListModel::changeTagId(int id)
{
    if (id == m_tagId)
        return false;

    m_tagId = id;
    emit tagIdChanged();
    return true;
}

bool DocumentListModel::changeCorrespondentId(int id)
{
    if (id == m_correspondentId)
        return false;

    m_correspondentId = id;
    emit correspondentIdChanged();
    return true;
}

bool DocumentListModel::changeOrdering(const QString &ordering)
{
    if (ordering == m_ordering)
        return false;

    m_ordering = ordering;
    emit orderingChanged();
    return true;
}

bool DocumentListModel::changeFilters(const QVariantMap &filters)
{
    if (filters == m_filters)
        return false;

    m_filters = filters;
    emit filtersChanged();
    return true;
}

void DocumentListModel::setSearchQuery(const QString &query)
{
    if (changeSearchQuery(query))
        reload();
}

void DocumentListModel::setTagId(int id)
{
    if (changeTagId(id))
        reload();
}

void DocumentListModel::setCorrespondentId(int id)
{
    if (changeCorrespondentId(id))
        reload();
}

void DocumentListModel::setOrdering(const QString &ordering)
{
    if (changeOrdering(ordering))
        reload();
}

void DocumentListModel::setFilters(const QVariantMap &filters)
{
    if (changeFilters(filters))
        reload();
}

void DocumentListModel::applyFilters(const QVariantMap &changes)
{
    bool changed = false;

    if (changes.contains(QStringLiteral("searchQuery")))
        changed |= changeSearchQuery(changes.value(QStringLiteral("searchQuery")).toString());
    if (changes.contains(QStringLiteral("tagId")))
        changed |= changeTagId(changes.value(QStringLiteral("tagId")).toInt());
    if (changes.contains(QStringLiteral("correspondentId")))
        changed |= changeCorrespondentId(changes.value(QStringLiteral("correspondentId")).toInt());
    if (changes.contains(QStringLiteral("ordering")))
        changed |= changeOrdering(changes.value(QStringLiteral("ordering")).toString());
    if (changes.contains(QStringLiteral("filters")))
        changed |= changeFilters(changes.value(QStringLiteral("filters")).toMap());

    if (changed)
        reload();
}

void DocumentListModel::removeDocument(int documentId)
{
    for (int row = 0; row < m_entries.count(); ++row) {
        if (m_entries.at(row).id != documentId)
            continue;

        beginRemoveRows(QModelIndex(), row, row);
        m_entries.remove(row);
        endRemoveRows();
        emit countChanged();
        break;
    }

    if (m_totalCount > 0) {
        --m_totalCount;
        emit totalCountChanged();
        // The number on the cover counts the whole archive, so it only follows
        // a list that is the whole archive.
        if (!hasFilters())
            m_api->setTotalDocuments(m_totalCount);
    }
}

void DocumentListModel::clearFilters()
{
    bool changed = changeSearchQuery(QString());
    changed |= changeTagId(-1);
    changed |= changeCorrespondentId(-1);
    changed |= changeFilters(QVariantMap());
    // A view can leave an order of its own behind, and clearing the filters
    // means going back to the list the app opens with, newest first.
    changed |= changeOrdering(defaultOrdering());

    if (changed)
        reload();
}

QString DocumentListModel::defaultOrdering()
{
    return QStringLiteral("-created");
}

void DocumentListModel::invalidate()
{
    ++m_generation;
    m_loadedAt = QDateTime();
    m_endReached = false;
    setRequest(NoRequest);
}

void DocumentListModel::clear()
{
    invalidate();

    if (!m_entries.isEmpty()) {
        beginResetModel();
        m_entries.clear();
        endResetModel();
        emit countChanged();
    }

    if (m_totalCount != 0) {
        m_totalCount = 0;
        emit totalCountChanged();
    }

    setErrorString(QString());
    setSearchRejected(false);
}

void DocumentListModel::reload()
{
    // The documents on screen are the answer to the previous query, and they
    // stay until the answer to this one arrives to replace them. A search term
    // the server cannot parse, which is what a half-typed one is, then costs
    // the user nothing.
    invalidate();
    setErrorString(QString());
    setSearchRejected(false);
    fetchPage(1, ReplaceRequest);
}

void DocumentListModel::refresh()
{
    // A list that was never read has nothing to merge into.
    if (m_entries.isEmpty()) {
        reload();
        return;
    }

    if (m_request != NoRequest)
        return;

    fetchPage(1, RefreshRequest);
}

void DocumentListModel::refreshIfStale(int seconds)
{
    if (m_request != NoRequest || !paperlessIsStale(m_loadedAt, seconds))
        return;

    refresh();
}

void DocumentListModel::loadMore()
{
    if (!canLoadMore())
        return;

    // The page is read off the list itself rather than counted up from the last
    // reply: after a merge the list can hold a few documents more or fewer than
    // a whole number of pages, and this still asks for the page the end of the
    // list sits in. Documents already held are dropped when the reply arrives.
    fetchPage(m_entries.count() / PageSize + 1, PageRequest);
}

QUrl DocumentListModel::pageUrl(int page) const
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page"), QString::number(page));
    query.addQueryItem(QStringLiteral("page_size"), QString::number(PageSize));
    // The tiebreaker only widens the query; m_ordering stays the field the user
    // chose, which is what a saved view is recognised by.
    query.addQueryItem(QStringLiteral("ordering"), orderingWithTiebreak(m_ordering));
    // Without this the server sends every field it has, and the text it read
    // out of the documents is by far the largest of them: a page of 25 comes to
    // several megabytes of words this list has no use for, which the phone then
    // spends the better part of a second parsing. A server too old to know the
    // parameter ignores it and answers as it always did.
    query.addQueryItem(QStringLiteral("fields"), QStringLiteral(
                           "id,title,created,added,correspondent,document_type,tags,"
                           "original_file_name,archive_serial_number,page_count"));
    if (!m_searchQuery.isEmpty())
        query.addQueryItem(QStringLiteral("query"), m_searchQuery);
    if (m_tagId > 0)
        query.addQueryItem(QStringLiteral("tags__id__all"), QString::number(m_tagId));
    if (m_correspondentId > 0)
        query.addQueryItem(QStringLiteral("correspondent__id"), QString::number(m_correspondentId));
    for (QVariantMap::const_iterator it = m_filters.constBegin(); it != m_filters.constEnd(); ++it)
        query.addQueryItem(it.key(), it.value().toString());

    return m_api->apiUrl(QStringLiteral("documents"), query);
}

void DocumentListModel::fetchPage(int page, Request kind)
{
    if (!m_api->isAuthenticated())
        return;

    m_expectedRows = m_entries.count();
    setRequest(kind);

    const int generation = m_generation;
    m_api->getJson(pageUrl(page), [this, generation, page, kind](const QJsonDocument &document,
                                                                 const QString &error, int status) {
        // The query this reply answers is no longer the query the list is for.
        if (generation != m_generation)
            return;

        if (!error.isEmpty()) {
            // A search the server refuses to parse is not a failure but a term
            // that is not finished yet: the documents stay and the field says
            // so. Anything else that goes wrong while replacing the list does
            // mean the documents on screen answer a question nobody is asking,
            // so they go and the reason takes their place.
            if (status == 400 && !m_searchQuery.isEmpty()) {
                setSearchRejected(true);
            } else if (kind == ReplaceRequest) {
                clear();
                setErrorString(error);
            } else {
                reportError(error);
            }

            setRequest(NoRequest);
            return;
        }

        const QJsonObject root = document.object();
        const int total = root.value(QStringLiteral("count")).toInt();

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

        setErrorString(QString());
        setSearchRejected(false);

        const bool totalChanged = total != m_totalCount;
        m_totalCount = total;
        if (!hasFilters())
            m_api->setTotalDocuments(total);

        if (page == 1)
            m_loadedAt = QDateTime::currentDateTimeUtc();

        // The rows are changed while the request still counts as in flight, so
        // a binding that reacts to the change and asks for another page is
        // turned away rather than let in on a half-updated list.
        switch (kind) {
        case ReplaceRequest:
            applyReplace(entries);
            break;
        case RefreshRequest:
            applyRefresh(entries);
            break;
        case PageRequest:
            applyPage(entries);
            break;
        case NoRequest:
            break;
        }

        if (totalChanged)
            emit totalCountChanged();

        setRequest(NoRequest);
    });
}

void DocumentListModel::applyReplace(const QVector<Entry> &entries)
{
    // The list is now the first page of the new query, and nothing of the old
    // one is kept: it described other documents in another order. Asking the
    // same question twice, which is what a pull to refresh often is, changes
    // nothing and is left alone.
    if (m_entries == entries)
        return;

    const int before = m_entries.count();

    beginResetModel();
    m_entries = entries;
    endResetModel();

    if (m_entries.count() != before)
        emit countChanged();
}

void DocumentListModel::applyRefresh(const QVector<Entry> &head)
{
    // The first page is the head of the list as the server has it now, and its
    // last document says where the rest of the list carries on from: both lists
    // are in the same order, so everything down to that document is described by
    // the page, and everything the list held after it still follows it. What
    // arrived since comes in at the top, what was deleted goes, and what only
    // changed its title or its tags is redrawn where it is.
    QVector<Entry> merged = head;

    if (head.count() == PageSize) {
        const int anchor = head.last().id;
        int joinsAt = -1;
        for (int i = 0; i < m_entries.count(); ++i) {
            if (m_entries.at(i).id == anchor) {
                joinsAt = i;
                break;
            }
        }

        // Without the last document of the page the list cannot say which of the
        // documents it holds come after it, so it keeps the page and pages the
        // rest in again. It takes more deletions than the list has pages for.
        if (joinsAt >= 0) {
            merged.reserve(head.count() + m_entries.count() - joinsAt - 1);
            for (int i = joinsAt + 1; i < m_entries.count(); ++i)
                merged.append(m_entries.at(i));
        } else {
            m_endReached = false;
        }
    }

    QSet<int> mergedIds;
    for (int i = 0; i < merged.count(); ++i)
        mergedIds.insert(merged.at(i).id);

    // What the list holds that the merged list also holds, in the order the list
    // holds it. The rows are changed into the merged list by taking away and
    // putting in, never by replacing the lot, so the view keeps its place; that
    // only works while these rows come in the same order on both sides.
    QVector<Entry> survivors;
    survivors.reserve(m_entries.count());
    for (int i = 0; i < m_entries.count(); ++i) {
        if (mergedIds.contains(m_entries.at(i).id))
            survivors.append(m_entries.at(i));
    }

    int matched = 0;
    for (int i = 0; i < merged.count() && matched < survivors.count(); ++i) {
        if (merged.at(i).id == survivors.at(matched).id)
            ++matched;
    }

    const int before = m_entries.count();

    // Documents have changed places among themselves, which no amount of taking
    // away and putting in describes. Rare enough to be worth a fresh list.
    if (matched != survivors.count()) {
        beginResetModel();
        m_entries = merged;
        endResetModel();
        if (m_entries.count() != before)
            emit countChanged();
        return;
    }

    for (int i = m_entries.count() - 1; i >= 0; --i) {
        if (mergedIds.contains(m_entries.at(i).id))
            continue;

        const int last = i;
        while (i > 0 && !mergedIds.contains(m_entries.at(i - 1).id))
            --i;

        beginRemoveRows(QModelIndex(), i, last);
        m_entries.remove(i, last - i + 1);
        endRemoveRows();
    }

    int at = 0;
    while (at < merged.count()) {
        if (at < m_entries.count() && m_entries.at(at).id == merged.at(at).id) {
            if (m_entries.at(at) != merged.at(at)) {
                m_entries[at] = merged.at(at);
                emit dataChanged(index(at, 0), index(at, 0));
            }
            ++at;
            continue;
        }

        // A run of documents the list does not hold at this place, up to the one
        // it does hold there.
        int last = at;
        while (last < merged.count()
               && !(at < m_entries.count() && m_entries.at(at).id == merged.at(last).id)) {
            ++last;
        }

        beginInsertRows(QModelIndex(), at, last - 1);
        for (int i = last - 1; i >= at; --i)
            m_entries.insert(at, merged.at(i));
        endInsertRows();
        at = last;
    }

    if (m_entries.count() != before)
        emit countChanged();
}

void DocumentListModel::applyPage(const QVector<Entry> &entries)
{
    // The list has to be the one the request was sent for. Without this, a page
    // could be appended to a list that has meanwhile been emptied or merged,
    // which is how the list used to end up starting halfway down the archive.
    if (m_entries.count() != m_expectedRows)
        return;

    QSet<int> knownIds;
    for (int i = 0; i < m_entries.count(); ++i)
        knownIds.insert(m_entries.at(i).id);

    QVector<Entry> fresh;
    fresh.reserve(entries.count());
    for (int i = 0; i < entries.count(); ++i) {
        if (!knownIds.contains(entries.at(i).id))
            fresh.append(entries.at(i));
    }

    // The server had only documents the list already holds: whatever the count
    // says, there is nothing below this, and asking again would ask the same.
    if (fresh.isEmpty()) {
        m_endReached = true;
        return;
    }

    beginInsertRows(QModelIndex(), m_entries.count(), m_entries.count() + fresh.count() - 1);
    m_entries += fresh;
    endInsertRows();
    emit countChanged();
}
