#ifndef PAPERLESS_CUSTOMFIELDSMODEL_H
#define PAPERLESS_CUSTOMFIELDSMODEL_H

#include <QAbstractListModel>
#include <QHash>
#include <QString>
#include <QVector>

class PaperlessApi;

// The custom fields defined on the server, needed to label and edit the
// values that documents carry. Accounts without the matching permission get an
// empty model, in which case the app hides custom fields entirely.
class CustomFieldsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool available READ isAvailable NOTIFY availableChanged)

public:
    enum Roles {
        FieldIdRole = Qt::UserRole + 1,
        NameRole,
        DataTypeRole
    };

    explicit CustomFieldsModel(PaperlessApi *api, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isAvailable() const { return m_available; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE QString nameFor(int fieldId) const;
    Q_INVOKABLE QString dataTypeFor(int fieldId) const;

signals:
    void countChanged();
    void availableChanged();

private:
    struct Entry {
        int id;
        QString name;
        QString dataType;
    };

    PaperlessApi *m_api;
    QVector<Entry> m_entries;
    QHash<int, int> m_indexById;
    bool m_available;
};

#endif // PAPERLESS_CUSTOMFIELDSMODEL_H
