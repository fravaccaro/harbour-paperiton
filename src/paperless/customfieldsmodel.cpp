#include "customfieldsmodel.h"

#include "api.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrlQuery>

CustomFieldsModel::CustomFieldsModel(PaperlessApi *api, QObject *parent)
    : QAbstractListModel(parent)
    , m_api(api)
    , m_available(false)
{
    connect(m_api, &PaperlessApi::authenticatedChanged, this, [this]() {
        if (m_api->isAuthenticated())
            reload();
    });
}

int CustomFieldsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QHash<int, QByteArray> CustomFieldsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(FieldIdRole, "fieldId");
    roles.insert(NameRole, "name");
    roles.insert(DataTypeRole, "dataType");
    return roles;
}

QVariant CustomFieldsModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.count())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case FieldIdRole:
        return entry.id;
    case NameRole:
        return entry.name;
    case DataTypeRole:
        return entry.dataType;
    default:
        return QVariant();
    }
}

QString CustomFieldsModel::nameFor(int fieldId) const
{
    const int index = m_indexById.value(fieldId, -1);
    return index < 0 ? QString() : m_entries.at(index).name;
}

QString CustomFieldsModel::dataTypeFor(int fieldId) const
{
    const int index = m_indexById.value(fieldId, -1);
    return index < 0 ? QString() : m_entries.at(index).dataType;
}

void CustomFieldsModel::reload()
{
    if (!m_api->isAuthenticated())
        return;

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page_size"), QStringLiteral("200"));

    m_api->getJson(m_api->apiUrl(QStringLiteral("custom_fields"), query),
                   [this](const QJsonDocument &document, const QString &error) {
        const bool available = error.isEmpty();
        QVector<Entry> entries;

        if (available) {
            const QJsonArray results = document.object().value(QStringLiteral("results")).toArray();
            for (int i = 0; i < results.count(); ++i) {
                const QJsonObject object = results.at(i).toObject();

                Entry entry;
                entry.id = object.value(QStringLiteral("id")).toInt();
                entry.name = object.value(QStringLiteral("name")).toString();
                entry.dataType = object.value(QStringLiteral("data_type")).toString();
                entries.append(entry);
            }
        }

        beginResetModel();
        m_entries = entries;
        m_indexById.clear();
        for (int i = 0; i < m_entries.count(); ++i)
            m_indexById.insert(m_entries.at(i).id, i);
        endResetModel();
        emit countChanged();

        if (available != m_available) {
            m_available = available;
            emit availableChanged();
        }
    }, true);
}
