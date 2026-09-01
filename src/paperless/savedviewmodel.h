#ifndef PAPERLESS_SAVEDVIEWMODEL_H
#define PAPERLESS_SAVEDVIEWMODEL_H

#include <QAbstractListModel>
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
    // Query parameters for the view, plus an "ordering" entry when the view
    // defines a sort order.
    Q_INVOKABLE QVariantMap filtersFor(int index) const;
    Q_INVOKABLE QString orderingFor(int index) const;

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
    bool m_loading;
};

#endif // PAPERLESS_SAVEDVIEWMODEL_H
