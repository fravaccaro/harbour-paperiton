#include "savedviewmodel.h"

#include "api.h"
#include "documentlistmodel.h"
#include "staleness.h"

#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStringList>
#include <QUrlQuery>

namespace {

// Mirrors the rule types of the Paperless web interface. Rules that have no
// counterpart in the document list query are left out on purpose.
QString queryKeyForRule(int ruleType)
{
    switch (ruleType) {
    case 0: return QStringLiteral("title__icontains");
    case 1: return QStringLiteral("content__icontains");
    case 2: return QStringLiteral("archive_serial_number");
    case 3: return QStringLiteral("correspondent__id");
    case 4: return QStringLiteral("document_type__id");
    case 5: return QStringLiteral("is_in_inbox");
    case 6: return QStringLiteral("tags__id__all");
    case 7: return QStringLiteral("is_tagged");
    case 8: return QStringLiteral("created__date__lt");
    case 9: return QStringLiteral("created__date__gt");
    case 10: return QStringLiteral("created__year");
    case 11: return QStringLiteral("created__month");
    case 12: return QStringLiteral("created__day");
    case 13: return QStringLiteral("added__date__lt");
    case 14: return QStringLiteral("added__date__gt");
    case 15: return QStringLiteral("modified__date__lt");
    case 16: return QStringLiteral("modified__date__gt");
    case 17: return QStringLiteral("tags__id__none");
    case 18: return QStringLiteral("archive_serial_number__isnull");
    case 19: return QStringLiteral("title_content");
    case 20: return QStringLiteral("query");
    case 21: return QStringLiteral("more_like_id");
    case 22: return QStringLiteral("tags__id__in");
    case 23: return QStringLiteral("archive_serial_number__gt");
    case 24: return QStringLiteral("archive_serial_number__lt");
    case 25: return QStringLiteral("storage_path__id");
    default: return QString();
    }
}

}

SavedViewModel::SavedViewModel(PaperlessApi *api, QObject *parent)
    : QAbstractListModel(parent)
    , m_api(api)
    , m_loading(false)
{
}

int SavedViewModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QHash<int, QByteArray> SavedViewModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(ViewIdRole, "viewId");
    roles.insert(NameRole, "name");
    roles.insert(RuleCountRole, "ruleCount");
    roles.insert(SupportedRole, "supported");
    return roles;
}

QVariant SavedViewModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.count())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case ViewIdRole:
        return entry.id;
    case NameRole:
        return entry.name;
    case RuleCountRole:
        return entry.ruleCount;
    case SupportedRole:
        return entry.supported;
    default:
        return QVariant();
    }
}

QVariantMap SavedViewModel::filtersFor(int index) const
{
    if (index < 0 || index >= m_entries.count())
        return QVariantMap();
    return m_entries.at(index).filters;
}

QString SavedViewModel::orderingFor(int index) const
{
    if (index < 0 || index >= m_entries.count())
        return QString();
    return m_entries.at(index).ordering;
}

bool SavedViewModel::matches(int index, const QVariantMap &filters, const QString &ordering) const
{
    if (index < 0 || index >= m_entries.count())
        return false;

    const Entry &entry = m_entries.at(index);
    // A view that carries neither a rule this app understands nor a sort order
    // is indistinguishable from the plain document list, so it claims nothing.
    if (entry.filters.isEmpty() && entry.ordering.isEmpty())
        return false;

    // A view without an order of its own is shown in the order the list opens
    // with, which is what applying it leaves behind.
    const QString effectiveOrdering = entry.ordering.isEmpty()
            ? DocumentListModel::defaultOrdering() : entry.ordering;

    return entry.filters == filters && effectiveOrdering == ordering;
}

QString SavedViewModel::nameMatching(const QVariantMap &filters, const QString &ordering) const
{
    for (int i = 0; i < m_entries.count(); ++i) {
        if (matches(i, filters, ordering))
            return m_entries.at(i).name;
    }

    return QString();
}

void SavedViewModel::setLoading(bool loading)
{
    if (loading == m_loading)
        return;

    m_loading = loading;
    emit loadingChanged();
}

void SavedViewModel::reload()
{
    if (!m_api->isAuthenticated())
        return;

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page_size"), QStringLiteral("100"));

    setLoading(true);
    m_api->getJson(m_api->apiUrl(QStringLiteral("saved_views"), query),
                   [this](const QJsonDocument &document, const QString &error) {
        setLoading(false);
        if (!error.isEmpty())
            return;

        const QJsonArray results = document.object().value(QStringLiteral("results")).toArray();
        QVector<Entry> entries;
        for (int i = 0; i < results.count(); ++i) {
            const QJsonObject object = results.at(i).toObject();

            Entry entry;
            entry.id = object.value(QStringLiteral("id")).toInt();
            entry.name = object.value(QStringLiteral("name")).toString();
            entry.supported = true;

            const QString sortField = object.value(QStringLiteral("sort_field")).toString();
            if (!sortField.isEmpty()) {
                const bool reverse = object.value(QStringLiteral("sort_reverse")).toBool();
                entry.ordering = (reverse ? QStringLiteral("-") : QString()) + sortField;
            }

            // Several rules of the same type combine into one comma separated value.
            QHash<QString, QStringList> values;
            const QJsonArray rules = object.value(QStringLiteral("filter_rules")).toArray();
            entry.ruleCount = rules.count();
            for (int r = 0; r < rules.count(); ++r) {
                const QJsonObject rule = rules.at(r).toObject();
                const QString key = queryKeyForRule(rule.value(QStringLiteral("rule_type")).toInt(-1));
                if (key.isEmpty()) {
                    entry.supported = false;
                    continue;
                }

                values[key].append(rule.value(QStringLiteral("value")).toString());
            }

            for (QHash<QString, QStringList>::const_iterator it = values.constBegin();
                 it != values.constEnd(); ++it) {
                entry.filters.insert(it.key(), it.value().join(QStringLiteral(",")));
            }

            entries.append(entry);
        }

        beginResetModel();
        m_entries = entries;
        endResetModel();
        m_loadedAt = QDateTime::currentDateTimeUtc();
        emit countChanged();
    }, true);
}

void SavedViewModel::reloadIfStale(int seconds)
{
    if (m_loading || !paperlessIsStale(m_loadedAt, seconds))
        return;

    reload();
}
