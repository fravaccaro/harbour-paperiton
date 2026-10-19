#include "secretsstore.h"

#include <Secrets/collectionnamesrequest.h>
#include <Secrets/createcollectionrequest.h>
#include <Secrets/deletesecretrequest.h>
#include <Secrets/request.h>
#include <Secrets/result.h>
#include <Secrets/storedsecretrequest.h>
#include <Secrets/storesecretrequest.h>

namespace {

using namespace Sailfish::Secrets;

const QString CollectionName = QStringLiteral("paperiton");
const QString SecretName = QStringLiteral("api-token");

// Runs a request, hands the result to the caller and cleans up afterwards.
template <typename Request, typename Handler>
void run(Request *request, const Handler &handler)
{
    QObject::connect(request, &Sailfish::Secrets::Request::statusChanged,
                     request, [request, handler]() {
        if (request->status() != Sailfish::Secrets::Request::Finished)
            return;

        handler(request);
        request->deleteLater();
    });

    request->startRequest();
}

// Whether the daemon answered that there is nothing under that name, which is
// the normal state before the first sign in rather than something that failed.
bool isMissing(const Result &result)
{
    switch (result.errorCode()) {
    case Result::InvalidSecretError:
    case Result::InvalidSecretIdentifierError:
    case Result::InvalidCollectionError:
        return true;
    default:
        return false;
    }
}

}

SecretsStore::SecretsStore(QObject *parent)
    : QObject(parent)
    , m_collectionExists(false)
{
}

Sailfish::Secrets::Secret::Identifier SecretsStore::identifier() const
{
    return Secret::Identifier(SecretName, CollectionName,
                              SecretManager::DefaultEncryptedStoragePluginName);
}

Sailfish::Secrets::Secret::Identifier SecretsStore::legacyIdentifier() const
{
    // Up to 0.6 the token was a standalone secret of the plain storage plugin.
    // An empty collection name is what marks a secret as standalone.
    return Secret::Identifier(SecretName, QString(),
                              SecretManager::DefaultStoragePluginName);
}

void SecretsStore::load()
{
    // Asking for a secret of a collection that was never created answers with
    // an error that reads like a failure, so the collections are counted first.
    CollectionNamesRequest *request = new CollectionNamesRequest(this);
    request->setManager(&m_manager);
    request->setStoragePluginName(SecretManager::DefaultEncryptedStoragePluginName);

    run(request, [this](CollectionNamesRequest *request) {
        const Result result = request->result();
        if (result.code() != Result::Succeeded) {
            emit failed(result.errorMessage());
            return;
        }

        m_collectionExists = request->collectionNames().contains(CollectionName);
        if (m_collectionExists)
            loadFromCollection();
        else
            loadLegacy();
    });
}

void SecretsStore::loadFromCollection()
{
    StoredSecretRequest *request = new StoredSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(identifier());
    request->setUserInteractionMode(SecretManager::SystemInteraction);

    run(request, [this](StoredSecretRequest *request) {
        const Result result = request->result();
        if (result.code() == Result::Succeeded) {
            emit loaded(QString::fromUtf8(request->secret().data()));
            return;
        }

        // The collection is there but holds no token of ours: an install that
        // signed out, or one still carrying what an older version wrote.
        if (isMissing(result)) {
            loadLegacy();
            return;
        }

        emit failed(result.errorMessage());
    });
}

void SecretsStore::loadLegacy()
{
    StoredSecretRequest *request = new StoredSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(legacyIdentifier());
    request->setUserInteractionMode(SecretManager::SystemInteraction);

    run(request, [this](StoredSecretRequest *request) {
        const Result result = request->result();
        if (result.code() == Result::Succeeded) {
            const QString token = QString::fromUtf8(request->secret().data());

            // The token is good for this run whether or not it reaches its new
            // home, and the old copy only goes once the new one is written, so
            // a migration that did not get through is simply tried again next
            // time rather than leaving nothing behind.
            writeToken(token, [this, token](bool stored) {
                if (stored)
                    removeLegacy();
                emit loaded(token);
            });
            return;
        }

        if (isMissing(result)) {
            emit loaded(QString());
            return;
        }

        emit failed(result.errorMessage());
    });
}

void SecretsStore::save(const QString &token)
{
    writeToken(token, [](bool) {});
}

void SecretsStore::writeToken(const QString &token, const std::function<void(bool)> &then)
{
    ensureCollection([this, token, then](bool ready) {
        if (!ready) {
            then(false);
            return;
        }

        // Sailfish Secrets has no way to replace a secret: storing over one
        // that is already there is refused. So the old one goes first, and how
        // that went is of no interest, since having nothing stored is the
        // normal state before the first sign in.
        DeleteSecretRequest *request = new DeleteSecretRequest(this);
        request->setManager(&m_manager);
        request->setIdentifier(identifier());
        request->setUserInteractionMode(SecretManager::SystemInteraction);

        run(request, [this, token, then](DeleteSecretRequest *) {
            storeToken(token, then);
        });
    });
}

void SecretsStore::storeToken(const QString &token, const std::function<void(bool)> &then)
{
    Secret secret(identifier());
    secret.setType(Secret::TypeBlob);
    secret.setData(token.toUtf8());

    StoreSecretRequest *request = new StoreSecretRequest(this);
    request->setManager(&m_manager);
    request->setSecretStorageType(StoreSecretRequest::CollectionSecret);
    request->setUserInteractionMode(SecretManager::SystemInteraction);
    request->setSecret(secret);

    run(request, [this, then](StoreSecretRequest *request) {
        const Result result = request->result();
        const bool stored = result.code() == Result::Succeeded;
        if (!stored)
            emit failed(result.errorMessage());
        then(stored);
    });
}

void SecretsStore::ensureCollection(const std::function<void(bool)> &then)
{
    if (m_collectionExists) {
        then(true);
        return;
    }

    CreateCollectionRequest *request = new CreateCollectionRequest(this);
    request->setManager(&m_manager);
    request->setCollectionName(CollectionName);
    request->setCollectionLockType(CreateCollectionRequest::DeviceLock);
    request->setDeviceLockUnlockSemantic(SecretManager::DeviceLockKeepUnlocked);
    request->setAccessControlMode(SecretManager::OwnerOnlyMode);
    request->setStoragePluginName(SecretManager::DefaultEncryptedStoragePluginName);
    request->setEncryptionPluginName(SecretManager::DefaultEncryptedStoragePluginName);

    run(request, [this, then](CreateCollectionRequest *request) {
        const Result result = request->result();
        const bool ready = result.code() == Result::Succeeded
                || result.errorCode() == Result::CollectionAlreadyExistsError;
        if (!ready) {
            emit failed(result.errorMessage());
            then(false);
            return;
        }

        m_collectionExists = true;
        then(true);
    });
}

void SecretsStore::remove()
{
    DeleteSecretRequest *request = new DeleteSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(identifier());
    request->setUserInteractionMode(SecretManager::SystemInteraction);

    run(request, [](DeleteSecretRequest *) {});

    // An install that never got as far as a successful migration still has the
    // token an older version wrote, and signing out has to take that one too.
    removeLegacy();
}

void SecretsStore::removeLegacy()
{
    DeleteSecretRequest *request = new DeleteSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(legacyIdentifier());
    request->setUserInteractionMode(SecretManager::SystemInteraction);

    run(request, [](DeleteSecretRequest *) {});
}
