#ifndef PAPERLESS_SECRETSSTORE_H
#define PAPERLESS_SECRETSSTORE_H

#include <QObject>
#include <QString>

#include <Secrets/secret.h>
#include <Secrets/secretmanager.h>

// Keeps the API token in the Sailfish Secrets daemon instead of the app's
// settings file. The token is stored as a standalone device-lock secret, which
// stays readable while the device is unlocked and needs no user interaction.
class SecretsStore : public QObject
{
    Q_OBJECT

public:
    explicit SecretsStore(QObject *parent = nullptr);

    void load();
    void save(const QString &token);
    void remove();

signals:
    // Carries an empty token when nothing has been stored yet.
    void loaded(const QString &token);
    void failed(const QString &error);

private:
    Sailfish::Secrets::Secret::Identifier identifier() const;
    void store(const QString &token);

    Sailfish::Secrets::SecretManager m_manager;
};

#endif // PAPERLESS_SECRETSSTORE_H
