#ifndef PAPERLESS_API_H
#define PAPERLESS_API_H

#include <QByteArray>
#include <QJsonDocument>
#include <QObject>
#include <QSet>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

class Config;
class QHttpMultiPart;
class QJsonObject;
class QNetworkAccessManager;
class QNetworkReply;
class QUrlQuery;

class PaperlessApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool authenticated READ isAuthenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int totalDocuments READ totalDocuments NOTIFY totalDocumentsChanged)
    // Set when the account can sign in but cannot read documents.
    Q_PROPERTY(QString accessWarning READ accessWarning NOTIFY accessWarningChanged)
    // True once the server has told which operations the account may perform.
    Q_PROPERTY(bool permissionsKnown READ permissionsKnown NOTIFY permissionsChanged)

public:
    typedef std::function<void(const QByteArray &data, const QString &error)> DataCallback;
    typedef std::function<void(const QJsonDocument &json, const QString &error)> JsonCallback;
    typedef std::function<void(qint64 sent, qint64 total)> ProgressCallback;

    explicit PaperlessApi(Config *config, QObject *parent = nullptr);

    Config *config() const { return m_config; }

    bool isAuthenticated() const;
    bool isBusy() const { return m_pending > 0; }
    QString lastError() const { return m_lastError; }
    int totalDocuments() const { return m_totalDocuments; }
    void setTotalDocuments(int count);
    QString accessWarning() const { return m_accessWarning; }
    bool permissionsKnown() const { return m_permissionsKnown; }

    // Generic helpers used by the models and the image provider.
    void getJson(const QUrl &url, const JsonCallback &callback, bool quiet = false);
    void getData(const QUrl &url, const DataCallback &callback);
    void sendJson(const QByteArray &verb, const QUrl &url, const QJsonObject &body,
                  const JsonCallback &callback);
    void deleteResource(const QUrl &url, const JsonCallback &callback);
    QUrl apiUrl(const QString &path, const QUrlQuery &query) const;
    QUrl documentFileUrl(int documentId, const QString &kind) const;

    Q_INVOKABLE void login(const QString &serverUrl, const QString &username, const QString &password);
    Q_INVOKABLE void loginWithToken(const QString &serverUrl, const QString &token);
    Q_INVOKABLE void logout();

    // Reads the sign in page of the server to find out whether it offers
    // single sign-on, and whether a password can be used at all.
    Q_INVOKABLE void detectSignInOptions(const QString &serverUrl);

    // Confirms after a sign in that the account may actually read documents and
    // learns which write operations the server allows.
    Q_INVOKABLE void checkAccess();
    Q_INVOKABLE bool can(const QString &permission) const;

    Q_INVOKABLE void fetchDocument(int documentId);
    // Downloads a document into the private cache directory, where only this
    // app can read it, for viewing inside the app.
    Q_INVOKABLE void saveDocument(int documentId, const QString &fileName, bool original);
    // Saves a document where the user keeps files, which is also the only way
    // another app can open it: the cache directory is invisible outside this
    // sandbox. The destination is "documents" or, by default, "downloads".
    Q_INVOKABLE void exportDocument(int documentId, const QString &fileName, bool original,
                                    const QString &destination = QString());
    // Everything the app has written into the cache, including thumbnails and
    // the web view profile. Used when signing out.
    Q_INVOKABLE void clearCache();
    // The document copies and camera captures only, which are scratch files.
    // Used when the app starts and when it quits.
    Q_INVOKABLE void clearTransientCache();
    Q_INVOKABLE QUrl fileUrl(const QString &path) const;
    Q_INVOKABLE QUrl webUrl(const QString &path) const;

    Q_INVOKABLE void patchDocument(int documentId, const QVariantMap &fields);
    Q_INVOKABLE void bulkEdit(const QVariantList &documentIds, const QString &method,
                              const QVariantMap &parameters);

    Q_INVOKABLE void fetchNotes(int documentId);
    Q_INVOKABLE void addNote(int documentId, const QString &note);
    Q_INVOKABLE void deleteNote(int documentId, int noteId);

    void uploadDocument(const QString &filePath, const QVariantMap &metadata,
                        const DataCallback &callback, const ProgressCallback &progress);
    void fetchTasks(const QString &taskId, const JsonCallback &callback);
    void acknowledgeTasks(const QVariantList &taskIds, const JsonCallback &callback);

signals:
    void authenticatedChanged();
    void busyChanged();
    void lastErrorChanged();
    void totalDocumentsChanged();
    void accessWarningChanged();
    void permissionsChanged();

    void loginSucceeded();
    void loginFailed(const QString &error);
    void signInOptionsDetected(const QStringList &providers, bool passwordSignIn);

    void documentFetched(int documentId, const QVariantMap &document);
    void documentFetchFailed(int documentId, const QString &error);

    void documentSaveStarted(int documentId);
    void documentSaved(int documentId, const QString &filePath);
    void documentExported(int documentId, const QString &filePath);
    void documentSaveFailed(int documentId, const QString &error);

    void documentUpdated(int documentId, const QVariantMap &document);
    void documentUpdateFailed(int documentId, const QString &error);

    void bulkEditFinished(const QString &error);

    void notesFetched(int documentId, const QVariantList &notes);
    void notesFailed(int documentId, const QString &error);

private:
    struct RequestContext {
        RequestContext() : isPost(false), authorized(true), quiet(false), multiPart(nullptr) {}

        QByteArray verb;
        QByteArray body;
        bool isPost;
        bool authorized;
        // Keeps a failure out of lastError, for probes that may legitimately fail.
        bool quiet;
        // Owned by the reply once the request has been sent.
        QHttpMultiPart *multiPart;
        ProgressCallback progress;
        // Overrides the stored token while signing in with a pasted token.
        QString token;
    };

    void dispatch(const QUrl &url, const RequestContext &context,
                  const DataCallback &callback, int redirectsLeft);
    void send(QNetworkReply *reply, const DataCallback &callback, int redirectsLeft);
    void beginRequest();
    void endRequest();
    void setLastError(const QString &error);
    void setAccessWarning(const QString &warning);
    void applyLogin(const QString &serverUrl, const QString &username, const QString &token);
    void downloadDocument(int documentId, const QString &fileName, bool original,
                          const QString &directory, bool unique, bool exported);

    Config *m_config;
    QNetworkAccessManager *m_network;
    QString m_lastError;
    QString m_accessWarning;
    QSet<QString> m_permissions;
    int m_pending;
    int m_totalDocuments;
    bool m_sendApiVersion;
    bool m_permissionsKnown;
};

#endif // PAPERLESS_API_H
