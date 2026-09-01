#include "api.h"

#include "config.h"

#include <QBuffer>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QStringList>
#include <QHttpMultiPart>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegExp>
#include <QSslError>
#include <QStandardPaths>
#include <QTimer>
#include <QUrlQuery>

namespace {

const int RequestTimeoutMs = 30000;
const int MaxRedirects = 3;

QString translated(const char *text)
{
    return QCoreApplication::translate("PaperlessApi", text);
}

void applyHeaders(QNetworkRequest &request, const QString &token, bool withApiVersion)
{
    request.setRawHeader("Accept", withApiVersion ? "application/json; version=10"
                                                  : "application/json");
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Paperiton (Sailfish OS)"));
    if (!token.isEmpty())
        request.setRawHeader("Authorization", "Token " + token.toUtf8());
}

// Paperless answers with either {"detail": "…"} or a map of field name to a
// list of messages. Showing that text is far more useful than "Bad Request".
QString extractServerMessage(const QByteArray &body)
{
    const QJsonDocument document = QJsonDocument::fromJson(body);
    if (!document.isObject())
        return QString();

    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("detail")).isString())
        return object.value(QStringLiteral("detail")).toString();

    QStringList messages;
    for (QJsonObject::const_iterator it = object.constBegin(); it != object.constEnd(); ++it) {
        QStringList texts;
        if (it.value().isString()) {
            texts.append(it.value().toString());
        } else if (it.value().isArray()) {
            const QJsonArray values = it.value().toArray();
            for (int i = 0; i < values.count(); ++i) {
                if (values.at(i).isString())
                    texts.append(values.at(i).toString());
            }
        }

        if (texts.isEmpty())
            continue;

        if (it.key() == QLatin1String("non_field_errors"))
            messages.append(texts.join(QStringLiteral(" ")));
        else
            messages.append(it.key() + QStringLiteral(": ") + texts.join(QStringLiteral(" ")));
    }

    return messages.join(QStringLiteral("\n"));
}

QString describeFailure(QNetworkReply *reply, int status, const QByteArray &body)
{
    const QString serverMessage = extractServerMessage(body);
    if (!serverMessage.isEmpty())
        return serverMessage;

    switch (status) {
    case 401:
    case 403:
        return translated("Not authorised. Check your credentials or API token.");
    case 404:
        return translated("Not found. Check the server address.");
    default:
        break;
    }

    if (status >= 500)
        return translated("The server reported an error (%1).").arg(status);

    switch (reply->error()) {
    case QNetworkReply::SslHandshakeFailedError:
        return translated("TLS handshake failed. For a self-signed certificate, enable "
                          "\"Ignore certificate errors\" in the settings.");
    case QNetworkReply::HostNotFoundError:
        return translated("Server not found. Check the address and your connection.");
    case QNetworkReply::OperationCanceledError:
        return translated("The request timed out.");
    default:
        break;
    }

    return reply->errorString();
}

QString uniqueFilePath(const QString &directory, const QString &fileName)
{
    const QFileInfo info(fileName);
    const QString base = info.completeBaseName();
    const QString suffix = info.suffix().isEmpty() ? QString() : QLatin1Char('.') + info.suffix();

    QString candidate = directory + QLatin1Char('/') + base + suffix;
    int counter = 2;
    while (QFile::exists(candidate)) {
        candidate = QStringLiteral("%1/%2 (%3)%4").arg(directory, base).arg(counter).arg(suffix);
        ++counter;
    }
    return candidate;
}

QString sanitizeFileName(const QString &name)
{
    QString clean = name;
    clean.replace(QRegExp(QStringLiteral("[/\\\\:*?\"<>|]")), QStringLiteral("_"));
    return clean.trimmed();
}

}

PaperlessApi::PaperlessApi(Config *config, QObject *parent)
    : QObject(parent)
    , m_config(config)
    , m_network(new QNetworkAccessManager(this))
    , m_pending(0)
    , m_totalDocuments(0)
    , m_sendApiVersion(true)
    , m_permissionsKnown(false)
{
    connect(m_config, &Config::configuredChanged, this, &PaperlessApi::authenticatedChanged);
}

bool PaperlessApi::isAuthenticated() const
{
    return m_config->isConfigured();
}

void PaperlessApi::setTotalDocuments(int count)
{
    if (count == m_totalDocuments)
        return;

    m_totalDocuments = count;
    emit totalDocumentsChanged();
}

void PaperlessApi::beginRequest()
{
    ++m_pending;
    if (m_pending == 1)
        emit busyChanged();
}

void PaperlessApi::endRequest()
{
    if (m_pending > 0)
        --m_pending;
    if (m_pending == 0)
        emit busyChanged();
}

void PaperlessApi::setLastError(const QString &error)
{
    if (error == m_lastError)
        return;

    m_lastError = error;
    emit lastErrorChanged();
}

void PaperlessApi::setAccessWarning(const QString &warning)
{
    if (warning == m_accessWarning)
        return;

    m_accessWarning = warning;
    emit accessWarningChanged();
}

QUrl PaperlessApi::apiUrl(const QString &path, const QUrlQuery &query) const
{
    return m_config->apiUrl(path, query);
}

QUrl PaperlessApi::documentFileUrl(int documentId, const QString &kind) const
{
    return m_config->apiUrl(QStringLiteral("documents/%1/%2").arg(documentId).arg(kind));
}

void PaperlessApi::dispatch(const QUrl &url, const RequestContext &context,
                            const DataCallback &callback, int redirectsLeft)
{
    QString token = context.token;
    if (token.isEmpty() && context.authorized)
        token = m_config->token();

    QNetworkRequest request(url);
    applyHeaders(request, token, m_sendApiVersion);

    QNetworkReply *reply;
    if (context.multiPart) {
        reply = m_network->post(request, context.multiPart);
        context.multiPart->setParent(reply);
    } else if (!context.verb.isEmpty()) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        if (context.verb == "DELETE") {
            reply = m_network->deleteResource(request);
        } else {
            QBuffer *buffer = new QBuffer;
            buffer->setData(context.body);
            buffer->open(QIODevice::ReadOnly);
            reply = m_network->sendCustomRequest(request, context.verb, buffer);
            buffer->setParent(reply);
        }
    } else if (context.isPost) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        reply = m_network->post(request, context.body);
    } else {
        reply = m_network->get(request);
    }

    reply->setProperty("verb", context.verb);
    reply->setProperty("postBody", context.body);
    reply->setProperty("isPost", context.isPost);
    reply->setProperty("authorized", context.authorized);
    reply->setProperty("quiet", context.quiet);
    reply->setProperty("token", context.token);
    // A multipart body cannot be replayed, so such requests are never retried.
    reply->setProperty("replayable", context.multiPart == nullptr);

    if (context.progress)
        connect(reply, &QNetworkReply::uploadProgress, this, context.progress);

    send(reply, callback, redirectsLeft);
}

void PaperlessApi::send(QNetworkReply *reply, const DataCallback &callback, int redirectsLeft)
{
    beginRequest();

    if (m_config->ignoreSslErrors()) {
        connect(reply, &QNetworkReply::sslErrors, reply,
                [reply](const QList<QSslError> &) { reply->ignoreSslErrors(); });
    }

    QTimer *timeout = new QTimer(reply);
    timeout->setSingleShot(true);
    timeout->setInterval(RequestTimeoutMs);
    connect(timeout, &QTimer::timeout, reply, &QNetworkReply::abort);
    timeout->start();

    connect(reply, &QNetworkReply::finished, this, [this, reply, callback, redirectsLeft]() {
        reply->deleteLater();
        endRequest();

        const QByteArray payload = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QUrl redirect = reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();

        RequestContext context;
        context.verb = reply->property("verb").toByteArray();
        context.body = reply->property("postBody").toByteArray();
        context.isPost = reply->property("isPost").toBool();
        context.authorized = reply->property("authorized").toBool();
        context.quiet = reply->property("quiet").toBool();
        context.token = reply->property("token").toString();
        const bool replayable = reply->property("replayable").toBool();

        if (!redirect.isEmpty() && redirectsLeft > 0 && replayable) {
            dispatch(reply->url().resolved(redirect), context, callback, redirectsLeft - 1);
            return;
        }

        // Servers that predate API version 10 answer 406; drop the pinned
        // version and let the server serve whatever it supports.
        if (status == 406 && m_sendApiVersion && replayable) {
            m_sendApiVersion = false;
            dispatch(reply->url(), context, callback, redirectsLeft);
            return;
        }

        if (reply->error() != QNetworkReply::NoError) {
            const QString message = describeFailure(reply, status, payload);
            if (!context.quiet)
                setLastError(message);
            callback(QByteArray(), message);
            return;
        }

        callback(payload, QString());
    });
}

void PaperlessApi::getData(const QUrl &url, const DataCallback &callback)
{
    if (m_config->serverUrl().isEmpty()) {
        callback(QByteArray(), translated("No server configured."));
        return;
    }

    dispatch(url, RequestContext(), callback, MaxRedirects);
}

namespace {

// Shared by every request that expects a JSON document back.
PaperlessApi::DataCallback jsonReader(const PaperlessApi::JsonCallback &callback)
{
    return [callback](const QByteArray &data, const QString &error) {
        if (!error.isEmpty()) {
            callback(QJsonDocument(), error);
            return;
        }

        // Successful deletes and acknowledgements answer with an empty body.
        if (data.trimmed().isEmpty()) {
            callback(QJsonDocument(), QString());
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError) {
            callback(QJsonDocument(), translated("The server did not return valid JSON."));
            return;
        }

        callback(document, QString());
    };
}

}

void PaperlessApi::getJson(const QUrl &url, const JsonCallback &callback, bool quiet)
{
    if (m_config->serverUrl().isEmpty()) {
        callback(QJsonDocument(), translated("No server configured."));
        return;
    }

    RequestContext context;
    context.quiet = quiet;
    dispatch(url, context, jsonReader(callback), MaxRedirects);
}

void PaperlessApi::sendJson(const QByteArray &verb, const QUrl &url, const QJsonObject &body,
                            const JsonCallback &callback)
{
    if (m_config->serverUrl().isEmpty()) {
        callback(QJsonDocument(), translated("No server configured."));
        return;
    }

    RequestContext context;
    context.verb = verb;
    context.body = QJsonDocument(body).toJson(QJsonDocument::Compact);
    dispatch(url, context, jsonReader(callback), MaxRedirects);
}

void PaperlessApi::deleteResource(const QUrl &url, const JsonCallback &callback)
{
    sendJson("DELETE", url, QJsonObject(), callback);
}

void PaperlessApi::applyLogin(const QString &serverUrl, const QString &username, const QString &token)
{
    m_config->setServerUrl(serverUrl);
    m_config->setUsername(username);
    m_config->setToken(token);
    setLastError(QString());
    checkAccess();
    emit loginSucceeded();
}

void PaperlessApi::checkAccess()
{
    if (!isAuthenticated())
        return;

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page_size"), QStringLiteral("1"));
    getJson(m_config->apiUrl(QStringLiteral("documents"), query),
            [this](const QJsonDocument &, const QString &error) {
        setAccessWarning(error);
    }, true);

    // Optional: accounts without the matching permission cannot read this, in
    // which case the server stays the only authority on what may be changed.
    getJson(m_config->apiUrl(QStringLiteral("ui_settings")),
            [this](const QJsonDocument &document, const QString &error) {
        m_permissions.clear();
        m_permissionsKnown = error.isEmpty();
        if (!m_permissionsKnown)
            return;

        const QJsonArray permissions = document.object().value(QStringLiteral("permissions")).toArray();
        for (int i = 0; i < permissions.count(); ++i)
            m_permissions.insert(permissions.at(i).toString());
    }, true);
}

bool PaperlessApi::can(const QString &permission) const
{
    // Without the permission list the app offers the action and lets the
    // server reject it, rather than hiding features that may well work.
    return !m_permissionsKnown || m_permissions.contains(permission);
}

void PaperlessApi::login(const QString &serverUrl, const QString &username, const QString &password)
{
    const QString normalized = Config::normalizeServerUrl(serverUrl);
    if (normalized.isEmpty()) {
        emit loginFailed(translated("Enter the address of your Paperless-ngx server."));
        return;
    }
    if (username.isEmpty() || password.isEmpty()) {
        emit loginFailed(translated("Enter your user name and password."));
        return;
    }

    QJsonObject payload;
    payload.insert(QStringLiteral("username"), username);
    payload.insert(QStringLiteral("password"), password);

    RequestContext context;
    context.body = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    context.isPost = true;
    context.authorized = false;

    dispatch(QUrl(normalized + QStringLiteral("/api/token/")), context,
             [this, normalized, username](const QByteArray &data, const QString &error) {
        if (!error.isEmpty()) {
            emit loginFailed(error);
            return;
        }

        const QJsonObject object = QJsonDocument::fromJson(data).object();
        const QString token = object.value(QStringLiteral("token")).toString();
        if (token.isEmpty()) {
            emit loginFailed(translated("The server did not return an API token."));
            return;
        }

        applyLogin(normalized, username, token);
    }, MaxRedirects);
}

void PaperlessApi::loginWithToken(const QString &serverUrl, const QString &token)
{
    const QString normalized = Config::normalizeServerUrl(serverUrl);
    if (normalized.isEmpty()) {
        emit loginFailed(translated("Enter the address of your Paperless-ngx server."));
        return;
    }
    if (token.trimmed().isEmpty()) {
        emit loginFailed(translated("Enter an API token."));
        return;
    }

    const QString cleanToken = token.trimmed();

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("page_size"), QStringLiteral("1"));
    QUrl url(normalized + QStringLiteral("/api/documents/"));
    url.setQuery(query);

    RequestContext context;
    context.token = cleanToken;

    dispatch(url, context, [this, normalized, cleanToken](const QByteArray &, const QString &error) {
        if (!error.isEmpty()) {
            emit loginFailed(error);
            return;
        }

        applyLogin(normalized, m_config->username(), cleanToken);
    }, MaxRedirects);
}

void PaperlessApi::logout()
{
    clearCache();
    m_config->clearCredentials();
    setTotalDocuments(0);
    setLastError(QString());
    setAccessWarning(QString());
    m_permissions.clear();
    m_permissionsKnown = false;
}

void PaperlessApi::fetchDocument(int documentId)
{
    const QUrl url = m_config->apiUrl(QStringLiteral("documents/%1").arg(documentId));
    getJson(url, [this, documentId](const QJsonDocument &document, const QString &error) {
        if (!error.isEmpty()) {
            emit documentFetchFailed(documentId, error);
            return;
        }

        emit documentFetched(documentId, document.object().toVariantMap());
    });
}

void PaperlessApi::saveDocument(int documentId, const QString &fileName, bool original)
{
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (directory.isEmpty() || !QDir().mkpath(directory)) {
        emit documentSaveFailed(documentId, translated("The Downloads folder is not available."));
        return;
    }

    QString name = sanitizeFileName(fileName);
    if (name.isEmpty())
        name = QStringLiteral("paperless-%1.pdf").arg(documentId);
    if (!name.contains(QLatin1Char('.')))
        name.append(QStringLiteral(".pdf"));

    emit documentSaveStarted(documentId);

    const QUrl url = documentFileUrl(documentId, original ? QStringLiteral("download")
                                                          : QStringLiteral("preview"));
    getData(url, [this, documentId, directory, name](const QByteArray &data, const QString &error) {
        if (!error.isEmpty()) {
            emit documentSaveFailed(documentId, error);
            return;
        }

        const QString path = uniqueFilePath(directory, name);
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly)) {
            emit documentSaveFailed(documentId, translated("Could not write to the Downloads folder."));
            return;
        }

        file.write(data);
        file.close();
        emit documentSaved(documentId, path);
    });
}

QUrl PaperlessApi::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path);
}

QUrl PaperlessApi::webUrl(const QString &path) const
{
    return m_config->webUrl(path);
}

void PaperlessApi::patchDocument(int documentId, const QVariantMap &fields)
{
    const QJsonObject body = QJsonObject::fromVariantMap(fields);
    sendJson("PATCH", m_config->apiUrl(QStringLiteral("documents/%1").arg(documentId)), body,
             [this, documentId](const QJsonDocument &document, const QString &error) {
        if (!error.isEmpty()) {
            emit documentUpdateFailed(documentId, error);
            return;
        }

        emit documentUpdated(documentId, document.object().toVariantMap());
    });
}

void PaperlessApi::bulkEdit(const QVariantList &documentIds, const QString &method,
                            const QVariantMap &parameters)
{
    QJsonArray ids;
    for (int i = 0; i < documentIds.count(); ++i)
        ids.append(documentIds.at(i).toInt());

    QJsonObject body;
    body.insert(QStringLiteral("documents"), ids);
    body.insert(QStringLiteral("method"), method);
    body.insert(QStringLiteral("parameters"), QJsonObject::fromVariantMap(parameters));

    sendJson("POST", m_config->apiUrl(QStringLiteral("documents/bulk_edit")), body,
             [this](const QJsonDocument &, const QString &error) {
        emit bulkEditFinished(error);
    });
}

void PaperlessApi::fetchNotes(int documentId)
{
    getJson(m_config->apiUrl(QStringLiteral("documents/%1/notes").arg(documentId)),
            [this, documentId](const QJsonDocument &document, const QString &error) {
        if (!error.isEmpty()) {
            emit notesFailed(documentId, error);
            return;
        }

        emit notesFetched(documentId, document.array().toVariantList());
    }, true);
}

void PaperlessApi::addNote(int documentId, const QString &note)
{
    QJsonObject body;
    body.insert(QStringLiteral("note"), note);

    sendJson("POST", m_config->apiUrl(QStringLiteral("documents/%1/notes").arg(documentId)), body,
             [this, documentId](const QJsonDocument &document, const QString &error) {
        if (!error.isEmpty()) {
            emit notesFailed(documentId, error);
            return;
        }

        // Both adding and removing a note answer with the remaining notes.
        emit notesFetched(documentId, document.array().toVariantList());
    });
}

void PaperlessApi::deleteNote(int documentId, int noteId)
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("id"), QString::number(noteId));

    deleteResource(m_config->apiUrl(QStringLiteral("documents/%1/notes").arg(documentId), query),
                   [this, documentId](const QJsonDocument &document, const QString &error) {
        if (!error.isEmpty()) {
            emit notesFailed(documentId, error);
            return;
        }

        emit notesFetched(documentId, document.array().toVariantList());
    });
}

void PaperlessApi::uploadDocument(const QString &filePath, const QVariantMap &metadata,
                                  const DataCallback &callback, const ProgressCallback &progress)
{
    QFile *file = new QFile(filePath);
    if (!file->open(QIODevice::ReadOnly)) {
        delete file;
        callback(QByteArray(), translated("The file could not be read."));
        return;
    }

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    QHttpPart documentPart;
    const QString name = QFileInfo(filePath).fileName();
    documentPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                           QStringLiteral("form-data; name=\"document\"; filename=\"%1\"").arg(name));
    documentPart.setHeader(QNetworkRequest::ContentTypeHeader,
                           QMimeDatabase().mimeTypeForFile(filePath).name());
    documentPart.setBodyDevice(file);
    file->setParent(multiPart);
    multiPart->append(documentPart);

    for (QVariantMap::const_iterator it = metadata.constBegin(); it != metadata.constEnd(); ++it) {
        // Tags are repeated, one part per id, as Django expects a list.
        QVariantList values = it.value().type() == QVariant::List ? it.value().toList()
                                                                  : QVariantList() << it.value();
        for (int i = 0; i < values.count(); ++i) {
            const QString text = values.at(i).toString();
            if (text.isEmpty())
                continue;

            QHttpPart part;
            part.setHeader(QNetworkRequest::ContentDispositionHeader,
                           QStringLiteral("form-data; name=\"%1\"").arg(it.key()));
            part.setBody(text.toUtf8());
            multiPart->append(part);
        }
    }

    RequestContext context;
    context.multiPart = multiPart;
    context.progress = progress;

    const QUrl url = m_config->apiUrl(QStringLiteral("documents/post_document"));
    dispatch(url, context, [callback](const QByteArray &data, const QString &error) {
        if (!error.isEmpty()) {
            callback(QByteArray(), error);
            return;
        }

        // The body is the quoted task id.
        QByteArray taskId = data.trimmed();
        if (taskId.startsWith('"') && taskId.endsWith('"'))
            taskId = taskId.mid(1, taskId.length() - 2);
        callback(taskId, QString());
    }, MaxRedirects);
}

void PaperlessApi::fetchTasks(const QString &taskId, const JsonCallback &callback)
{
    QUrlQuery query;
    if (!taskId.isEmpty())
        query.addQueryItem(QStringLiteral("task_id"), taskId);

    getJson(m_config->apiUrl(QStringLiteral("tasks"), query), callback, true);
}

void PaperlessApi::acknowledgeTasks(const QVariantList &taskIds, const JsonCallback &callback)
{
    QJsonArray ids;
    for (int i = 0; i < taskIds.count(); ++i)
        ids.append(taskIds.at(i).toInt());

    QJsonObject body;
    body.insert(QStringLiteral("tasks"), ids);

    sendJson("POST", m_config->apiUrl(QStringLiteral("acknowledge_tasks")), body, callback);
}

void PaperlessApi::clearCache()
{
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (cacheDir.isEmpty())
        return;

    QDir(cacheDir + QStringLiteral("/thumbnails")).removeRecursively();
}
