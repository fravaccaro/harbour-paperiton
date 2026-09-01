#ifndef PAPERLESS_CONFIG_H
#define PAPERLESS_CONFIG_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QUrl>
#include <QUrlQuery>

#include "secretsstore.h"

class Config : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString username READ username WRITE setUsername NOTIFY usernameChanged)
    Q_PROPERTY(QString token READ token WRITE setToken NOTIFY tokenChanged)
    Q_PROPERTY(bool ignoreSslErrors READ ignoreSslErrors WRITE setIgnoreSslErrors NOTIFY ignoreSslErrorsChanged)
    Q_PROPERTY(bool configured READ isConfigured NOTIFY configuredChanged)
    // False until the token has been read back from Sailfish Secrets.
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    Q_PROPERTY(QString secretsError READ secretsError NOTIFY secretsErrorChanged)

public:
    explicit Config(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    void setServerUrl(const QString &url);

    QString username() const { return m_username; }
    void setUsername(const QString &username);

    QString token() const { return m_token; }
    void setToken(const QString &token);

    bool ignoreSslErrors() const { return m_ignoreSslErrors; }
    void setIgnoreSslErrors(bool ignore);

    bool isConfigured() const { return !m_serverUrl.isEmpty() && !m_token.isEmpty(); }
    bool isReady() const { return m_ready; }
    QString secretsError() const { return m_secretsError; }

    // Builds <serverUrl>/api/<path>/?<query>. Paperless is Django based and
    // redirects slash-less URLs, which drops the Authorization header.
    QUrl apiUrl(const QString &path, const QUrlQuery &query = QUrlQuery()) const;

    // Points at a page of the Paperless web interface, for opening in the browser.
    Q_INVOKABLE QUrl webUrl(const QString &path) const;

    Q_INVOKABLE void clearCredentials();

    // Turns user input such as "paperless.lan" into "https://paperless.lan".
    Q_INVOKABLE static QString normalizeServerUrl(const QString &input);

signals:
    void serverUrlChanged();
    void usernameChanged();
    void tokenChanged();
    void ignoreSslErrorsChanged();
    void configuredChanged();
    void readyChanged();
    void secretsErrorChanged();

private:
    void store(const QString &key, const QVariant &value);
    void applyStoredToken(const QString &token);

    QSettings m_settings;
    SecretsStore m_secrets;
    QString m_serverUrl;
    QString m_username;
    QString m_token;
    QString m_secretsError;
    bool m_ignoreSslErrors;
    bool m_ready;
};

#endif // PAPERLESS_CONFIG_H
