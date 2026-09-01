#ifndef PAPERLESS_DOCUMENTLISTMODEL_H
#define PAPERLESS_DOCUMENTLISTMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class PaperlessApi;

class DocumentListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(int tagId READ tagId WRITE setTagId NOTIFY tagIdChanged)
    Q_PROPERTY(int correspondentId READ correspondentId WRITE setCorrespondentId NOTIFY correspondentIdChanged)
    Q_PROPERTY(QString ordering READ ordering WRITE setOrdering NOTIFY orderingChanged)
    // Extra query parameters, used for the inbox tag and for saved views.
    Q_PROPERTY(QVariantMap filters READ filters WRITE setFilters NOTIFY filtersChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(bool canLoadMore READ canLoadMore NOTIFY canLoadMoreChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

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

    explicit DocumentListModel(QObject *parent = nullptr);

    // Set once from main.cpp; the app talks to a single server.
    static void setApi(PaperlessApi *api);

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

    QVariantMap filters() const { return m_filters; }
    void setFilters(const QVariantMap &filters);

    int totalCount() const { return m_totalCount; }
    bool isLoading() const { return m_loading; }
    bool canLoadMore() const;
    QString errorString() const { return m_errorString; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadMore();
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
    };

    void fetchPage(int page);
    void setLoading(bool loading);
    void setErrorString(const QString &error);
    bool hasFilters() const;

    static PaperlessApi *s_api;

    QVector<Entry> m_entries;
    QString m_searchQuery;
    QString m_ordering;
    QVariantMap m_filters;
    int m_tagId;
    int m_correspondentId;
    int m_totalCount;
    int m_page;
    int m_generation;
    bool m_loading;
    QString m_errorString;
};

#endif // PAPERLESS_DOCUMENTLISTMODEL_H
