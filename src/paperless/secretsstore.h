#ifndef PAPERLESS_SECRETSSTORE_H
#define PAPERLESS_SECRETSSTORE_H

#include <functional>

#include <QObject>
#include <QString>

#include <Secrets/secret.h>
#include <Secrets/secretmanager.h>

// Keeps the API token in the Sailfish Secrets daemon instead of the app's
// settings file. The token is a secret of a device-lock collection in the
// encrypted storage plugin, and every read and write lets the system ask the
// user to unlock it. The daemon locks the collection again whenever it is
// restarted, a reboot among those times, so forbidding that question is what
// would turn a restart into a sign out.
class SecretsStore : public QObject
{
    Q_OBJECT

public:
    explicit SecretsStore(QObject *parent = nullptr);

    void load();
    void save(const QString &token);
    void remove();

signals:
    // Carries an empty token when nothing has been stored yet. A read that did
    // not get through answers with failed() alone: the token is still in the
    // collection, so reporting it as absent would sign the user out for nothing.
    void loaded(const QString &token);
    void failed(const QString &error);

private:
    Sailfish::Secrets::Secret::Identifier identifier() const;
    Sailfish::Secrets::Secret::Identifier legacyIdentifier() const;

    void loadFromCollection();
    void loadLegacy();
    void ensureCollection(const std::function<void(bool)> &then);
    void writeToken(const QString &token, const std::function<void(bool)> &then);
    void storeToken(const QString &token, const std::function<void(bool)> &then);
    void removeLegacy();

    Sailfish::Secrets::SecretManager m_manager;
    bool m_collectionExists;
};

#endif // PAPERLESS_SECRETSSTORE_H
