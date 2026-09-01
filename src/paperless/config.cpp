#include "config.h"

#include <QDir>
#include <QStandardPaths>
#include <QUrlQuery>

namespace {

QString settingsFilePath()
{
    // AppConfigLocation resolves to ~/.config/<org>/<app>, which is exactly the
    // directory Sailjail whitelists for the app's private data.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/settings.conf");
}

}

Config::Config(QObject *parent)
    : QObject(parent)
    , m_settings(settingsFilePath(), QSettings::IniFormat)
    , m_ignoreSslErrors(false)
    , m_ready(false)
{
    m_serverUrl = m_settings.value(QStringLiteral("server/url")).toString();
    m_username = m_settings.value(QStringLiteral("server/username")).toString();
    m_ignoreSslErrors = m_settings.value(QStringLiteral("server/ignoreSslErrors"), false).toBool();

    connect(&m_secrets, &SecretsStore::loaded, this, &Config::applyStoredToken);
    connect(&m_secrets, &SecretsStore::failed, this, [this](const QString &error) {
        m_secretsError = error;
        emit secretsErrorChanged();
    });
    m_secrets.load();
}

void Config::applyStoredToken(const QString &token)
{
    QString value = token;

    // Versions before 0.2 kept the token in the settings file.
    const QString legacyKey = QStringLiteral("server/token");
    if (m_settings.contains(legacyKey)) {
        const QString legacyToken = m_settings.value(legacyKey).toString();
        if (value.isEmpty() && !legacyToken.isEmpty()) {
            value = legacyToken;
            m_secrets.save(value);
        }
        m_settings.remove(legacyKey);
        m_settings.sync();
    }

    const bool wasConfigured = isConfigured();
    m_token = value;
    emit tokenChanged();
    if (wasConfigured != isConfigured())
        emit configuredChanged();

    m_ready = true;
    emit readyChanged();
}

void Config::store(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
    m_settings.sync();
}

void Config::setServerUrl(const QString &url)
{
    const QString normalized = normalizeServerUrl(url);
    if (normalized == m_serverUrl)
        return;

    const bool wasConfigured = isConfigured();
    m_serverUrl = normalized;
    store(QStringLiteral("server/url"), m_serverUrl);
    emit serverUrlChanged();
    if (wasConfigured != isConfigured())
        emit configuredChanged();
}

void Config::setUsername(const QString &username)
{
    if (username == m_username)
        return;

    m_username = username;
    store(QStringLiteral("server/username"), m_username);
    emit usernameChanged();
}

void Config::setToken(const QString &token)
{
    if (token == m_token)
        return;

    const bool wasConfigured = isConfigured();
    m_token = token;
    if (m_token.isEmpty())
        m_secrets.remove();
    else
        m_secrets.save(m_token);
    emit tokenChanged();
    if (wasConfigured != isConfigured())
        emit configuredChanged();
}

void Config::setIgnoreSslErrors(bool ignore)
{
    if (ignore == m_ignoreSslErrors)
        return;

    m_ignoreSslErrors = ignore;
    store(QStringLiteral("server/ignoreSslErrors"), m_ignoreSslErrors);
    emit ignoreSslErrorsChanged();
}

void Config::clearCredentials()
{
    setToken(QString());
}

QString Config::normalizeServerUrl(const QString &input)
{
    QString url = input.trimmed();
    if (url.isEmpty())
        return QString();

    if (!url.contains(QStringLiteral("://")))
        url.prepend(QStringLiteral("https://"));

    while (url.endsWith(QLatin1Char('/')))
        url.chop(1);

    return url;
}

QUrl Config::webUrl(const QString &path) const
{
    if (m_serverUrl.isEmpty())
        return QUrl();

    QString relative = path;
    while (relative.startsWith(QLatin1Char('/')))
        relative.remove(0, 1);

    return QUrl(m_serverUrl + QLatin1Char('/') + relative);
}

QUrl Config::apiUrl(const QString &path, const QUrlQuery &query) const
{
    QString relative = path;
    while (relative.startsWith(QLatin1Char('/')))
        relative.remove(0, 1);
    if (!relative.isEmpty() && !relative.endsWith(QLatin1Char('/')))
        relative.append(QLatin1Char('/'));

    QUrl url(m_serverUrl + QStringLiteral("/api/") + relative);
    if (!query.isEmpty())
        url.setQuery(query);
    return url;
}
