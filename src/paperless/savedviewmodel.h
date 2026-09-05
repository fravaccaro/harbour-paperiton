#ifndef PAPERLESS_SAVEDVIEWMODEL_H
#define PAPERLESS_SAVEDVIEWMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class PaperlessApi;

// The saved views of the server. Their filter rules are translated into the
// query parameters that DocumentListModel understands.
class SavedViewModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)

public:
    enum Roles {
        ViewIdRole = Qt::UserRole + 1,
        NameRole,
        RuleCountRole,
        SupportedRole
    };

    explicit SavedViewModel(PaperlessApi *api, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isLoading() const { return m_loading; }

    Q_INVOKABLE void reload();
    // Reloads only when the views were last read more than that many seconds
    // ago, so opening the filter page repeatedly does not ask again each time.
    Q_INVOKABLE void reloadIfStale(int seconds);
    // Query parameters for the view, plus an "ordering" entry when the view
    // defines a sort order.
    Q_INVOKABLE QVariantMap filtersFor(int index) const;
    Q_INVOKABLE QString orderingFor(int index) const;
    // True when a document list queried with these parameters is showing this
    // view, which is how the filter page marks the one in use.
    Q_INVOKABLE bool matches(int index, const QVariantMap &filters, const QString &ordering) const;
    // The name of the view a list queried with these parameters is showing, so
    // that the list can say which view it is searching inside of.
    Q_INVOKABLE QString nameMatching(const QVariantMap &filters, const QString &ordering) const;

signals:
    void countChanged();
    void loadingChanged();

private:
    struct Entry {
        int id;
        QString name;
        QVariantMap filters;
        QString ordering;
        int ruleCount;
        // False when the view uses rules this app cannot translate.
        bool supported;
    };

    void setLoading(bool loading);

    PaperlessApi *m_api;
    QVector<Entry> m_entries;
    QDateTime m_loadedAt;
    bool m_loading;
};

#endif // PAPERLESS_SAVEDVIEWMODEL_H
