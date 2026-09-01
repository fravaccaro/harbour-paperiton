#ifndef PAPERLESS_TASKLISTMODEL_H
#define PAPERLESS_TASKLISTMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QVector>

class PaperlessApi;

// The consumption queue of the server, as shown by the "Tasks" view of the web
// interface: files that are being processed, and the ones that failed.
class TaskListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(bool failedOnly READ failedOnly WRITE setFailedOnly NOTIFY failedOnlyChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    enum Roles {
        TaskIdRole = Qt::UserRole + 1,
        NameRole,
        FileNameRole,
        StatusRole,
        ResultRole,
        CreatedRole,
        DocumentIdRole,
        AcknowledgedRole
    };

    explicit TaskListModel(PaperlessApi *api, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isLoading() const { return m_loading; }
    bool failedOnly() const { return m_failedOnly; }
    void setFailedOnly(bool failedOnly);
    QString errorString() const { return m_errorString; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void acknowledge(int index);

signals:
    void countChanged();
    void loadingChanged();
    void failedOnlyChanged();
    void errorStringChanged();

private:
    struct Entry {
        int id;
        QString taskId;
        QString name;
        QString fileName;
        QString status;
        QString result;
        QDateTime created;
        int documentId;
        bool acknowledged;
    };

    void setLoading(bool loading);
    void setErrorString(const QString &error);

    PaperlessApi *m_api;
    QVector<Entry> m_entries;
    QString m_errorString;
    int m_generation;
    bool m_loading;
    bool m_failedOnly;
};

#endif // PAPERLESS_TASKLISTMODEL_H
