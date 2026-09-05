#ifndef PAPERLESS_DOCUMENTLISTMODEL_H
#define PAPERLESS_DOCUMENTLISTMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class PaperlessApi;

// The one list of documents the app shows. The list page and the filter page
// both work on this single instance, so what the user chose in one is what the
// other sees, and there is never a second copy of the archive being paged in
// the background.
class DocumentListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(int tagId READ tagId WRITE setTagId NOTIFY tagIdChanged)
    Q_PROPERTY(int correspondentId READ correspondentId WRITE setCorrespondentId NOTIFY correspondentIdChanged)
    Q_PROPERTY(QString ordering READ ordering WRITE setOrdering NOTIFY orderingChanged)
    // The order the list is in when no saved view asks for another one.
    Q_PROPERTY(QString defaultOrdering READ defaultOrdering CONSTANT)
    // Extra query parameters, used for the inbox tag and for saved views.
    Q_PROPERTY(QVariantMap filters READ filters WRITE setFilters NOTIFY filtersChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(bool canLoadMore READ canLoadMore NOTIFY canLoadMoreChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)
    // The server could not make sense of the search term, which is what half a
    // term looks like while it is still being typed.
    Q_PROPERTY(bool searchRejected READ searchRejected NOTIFY searchRejectedChanged)

public:
    enum Roles {
        DocumentIdRole = Qt::UserRole + 1,
        TitleRole,
        CreatedRole,
        AddedRole,
        CorrespondentIdRole,
        DocumentTypeIdRole,
        TagIdsRole,
        ThumbnailSourceRole,
        OriginalFileNameRole,
        ArchiveSerialNumberRole,
        PageCountRole
    };

    explicit DocumentListModel(PaperlessApi *api, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString searchQuery() const { return m_searchQuery; }
    void setSearchQuery(const QString &query);

    int tagId() const { return m_tagId; }
    void setTagId(int id);

    int correspondentId() const { return m_correspondentId; }
    void setCorrespondentId(int id);

    QString ordering() const { return m_ordering; }
    void setOrdering(const QString &ordering);
    static QString defaultOrdering();

    QVariantMap filters() const { return m_filters; }
    void setFilters(const QVariantMap &filters);

    int totalCount() const { return m_totalCount; }
    bool isLoading() const { return m_request != NoRequest; }
    bool canLoadMore() const;
    QString errorString() const { return m_errorString; }
    bool searchRejected() const { return m_searchRejected; }

    // Reads the list again from the top for a query that describes another set
    // of documents, and for a refresh the user asked for. What is on screen
    // stays there until the new list arrives to take its place.
    Q_INVOKABLE void reload();
    // Reads the first page again and merges it into the list in place, so the
    // documents that arrived since are picked up without the list blanking or
    // losing the place the user had scrolled to.
    Q_INVOKABLE void refresh();
    // Merges, but only if the list was last read more than that many seconds
    // ago; a short glance at the cover leaves the list alone.
    Q_INVOKABLE void refreshIfStale(int seconds);
    Q_INVOKABLE void loadMore();
    // Several parts of the query at once, named as the properties are. Set one
    // by one they would each start a request for a list nobody ever sees.
    Q_INVOKABLE void applyFilters(const QVariantMap &changes);
    Q_INVOKABLE void clearFilters();
    Q_INVOKABLE QVariantMap get(int index) const;

signals:
    void searchQueryChanged();
    void tagIdChanged();
    void correspondentIdChanged();
    void orderingChanged();
    void filtersChanged();
    void countChanged();
    void totalCountChanged();
    void loadingChanged();
    void canLoadMoreChanged();
    void errorStringChanged();
    void searchRejectedChanged();
    // A request that failed over a list which still holds documents: the
    // documents stay on screen, so the reason is told instead of shown.
    void loadFailed(const QString &error);

private:
    struct Entry {
        int id;
        QString title;
        QDateTime created;
        QDateTime added;
        int correspondentId;
        int documentTypeId;
        QVariantList tagIds;
        QString originalFileName;
        QVariant archiveSerialNumber;
        int pageCount;

        bool operator==(const Entry &other) const;
        bool operator!=(const Entry &other) const { return !(*this == other); }
    };

    // At most one of these is in flight at any time, which is what keeps a
    // reply from being applied to a list that has meanwhile become another one.
    enum Request {
        NoRequest,
        ReplaceRequest,
        RefreshRequest,
        PageRequest
    };

    // Each records the new value and announces it, and answers whether the
    // query changed; who called decides when the list is read again.
    bool changeSearchQuery(const QString &query);
    bool changeTagId(int id);
    bool changeCorrespondentId(int id);
    bool changeOrdering(const QString &ordering);
    bool changeFilters(const QVariantMap &filters);

    void fetchPage(int page, Request kind);
    void applyReplace(const QVector<Entry> &entries);
    void applyRefresh(const QVector<Entry> &entries);
    void applyPage(const QVector<Entry> &entries);
    void setRequest(Request request);
    void setErrorString(const QString &error);
    void setSearchRejected(bool rejected);
    void reportError(const QString &error);
    // Leaves the rows alone, but makes the list forget that anything is being
    // asked for: replies to the old query are turned away when they arrive.
    void invalidate();
    void clear();
    bool hasFilters() const;
    QUrl pageUrl(int page) const;

    PaperlessApi *m_api;
    QVector<Entry> m_entries;
    QDateTime m_loadedAt;
    QString m_searchQuery;
    QString m_ordering;
    QVariantMap m_filters;
    int m_tagId;
    int m_correspondentId;
    int m_totalCount;
    // The number of rows the list had when the request in flight was sent. A
    // reply is only applied to a list that still looks that way.
    int m_expectedRows;
    int m_generation;
    Request m_request;
    // Set when the server had nothing left to add below what is already held,
    // so the end of the list is not asked for over and over.
    bool m_endReached;
    bool m_searchRejected;
    QString m_errorString;
};

#endif // PAPERLESS_DOCUMENTLISTMODEL_H
