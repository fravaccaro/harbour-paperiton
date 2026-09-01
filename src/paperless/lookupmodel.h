#ifndef PAPERLESS_LOOKUPMODEL_H
#define PAPERLESS_LOOKUPMODEL_H

#include <QAbstractListModel>
#include <QHash>
#include <QString>
#include <QVector>

class PaperlessApi;

// Backs the small /api/tags/, /api/correspondents/ and /api/document_types/
// collections that are needed to turn the ids of a document into labels.
class LookupModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    // Only meaningful for tags: -1 when the server defines no inbox tag.
    Q_PROPERTY(int inboxTagId READ inboxTagId NOTIFY inboxTagIdChanged)

public:
    enum Roles {
        ItemIdRole = Qt::UserRole + 1,
        NameRole,
        ColorRole,
        TextColorRole,
        DocumentCountRole,
        IsInboxTagRole
    };

    LookupModel(PaperlessApi *api, const QString &endpoint, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isLoading() const { return m_loading; }
    bool isReady() const { return m_ready; }
    int inboxTagId() const { return m_inboxTagId; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE QString nameFor(int id) const;
    Q_INVOKABLE QString colorFor(int id) const;
    Q_INVOKABLE QString textColorFor(int id) const;
    Q_INVOKABLE QStringList namesFor(const QVariantList &ids) const;

signals:
    void countChanged();
    void loadingChanged();
    void readyChanged();
    void inboxTagIdChanged();

private:
    struct Entry {
        int id;
        QString name;
        QString color;
        QString textColor;
        int documentCount;
        bool isInboxTag;
    };

    void fetchPage(int page);
    void setLoading(bool loading);
    void setReady(bool ready);
    int indexOfId(int id) const;

    PaperlessApi *m_api;
    QString m_endpoint;
    QVector<Entry> m_entries;
    QVector<Entry> m_incoming;
    QHash<int, int> m_indexById;
    int m_generation;
    int m_inboxTagId;
    bool m_loading;
    bool m_ready;
};

#endif // PAPERLESS_LOOKUPMODEL_H
