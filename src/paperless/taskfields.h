#ifndef PAPERLESS_TASKFIELDS_H
#define PAPERLESS_TASKFIELDS_H

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

// A task tells the app what became of a file it uploaded. Version 10 of the API
// took the single freeform "result" apart into an "input_data" and a
// "result_data" of its own shape, and moved the document a task produced into a
// list, so both spellings are looked for: the older one still answers on a
// server that has not been updated.

// The document a task created, or the one an upload turned out to be a
// duplicate of, which is the one worth opening. -1 when the task has none.
inline int paperlessTaskDocumentId(const QJsonObject &task)
{
    const QJsonArray ids = task.value(QStringLiteral("related_document_ids")).toArray();
    for (int i = 0; i < ids.count(); ++i) {
        if (ids.at(i).isDouble())
            return ids.at(i).toInt();
    }

    const QJsonObject result = task.value(QStringLiteral("result_data")).toObject();
    const QStringList keys = QStringList()
            << QStringLiteral("document_id")
            << QStringLiteral("duplicate_of");
    for (int i = 0; i < keys.count(); ++i) {
        const QJsonValue value = result.value(keys.at(i));
        if (value.isDouble())
            return value.toInt();
    }

    return task.value(QStringLiteral("related_document")).toInt(-1);
}

// What the server has to say about the task, ready to be shown as it is. Empty
// when the task says nothing, which a successful one usually does.
inline QString paperlessTaskMessage(const QJsonObject &task)
{
    const QString message = task.value(QStringLiteral("result_message")).toString();
    if (!message.isEmpty())
        return message;

    const QJsonObject result = task.value(QStringLiteral("result_data")).toObject();
    const QString error = result.value(QStringLiteral("error_message")).toString();
    if (!error.isEmpty())
        return error;

    return task.value(QStringLiteral("result")).toString();
}

// The file the task was given, which is how the user recognises it.
inline QString paperlessTaskFileName(const QJsonObject &task)
{
    const QString fileName = task.value(QStringLiteral("task_file_name")).toString();
    if (!fileName.isEmpty())
        return fileName;

    return task.value(QStringLiteral("input_data")).toObject()
            .value(QStringLiteral("filename")).toString();
}

#endif // PAPERLESS_TASKFIELDS_H
