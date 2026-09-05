#include "secretsstore.h"

#include <Secrets/deletesecretrequest.h>
#include <Secrets/request.h>
#include <Secrets/result.h>
#include <Secrets/storedsecretrequest.h>
#include <Secrets/storesecretrequest.h>

namespace {

using namespace Sailfish::Secrets;

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

}

SecretsStore::SecretsStore(QObject *parent)
    : QObject(parent)
{
}

Sailfish::Secrets::Secret::Identifier SecretsStore::identifier() const
{
    // An empty collection name marks the secret as standalone.
    return Secret::Identifier(SecretName, QString(),
                              SecretManager::DefaultStoragePluginName);
}

void SecretsStore::load()
{
    StoredSecretRequest *request = new StoredSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(identifier());
    request->setUserInteractionMode(SecretManager::PreventInteraction);

    run(request, [this](StoredSecretRequest *request) {
        const Result result = request->result();
        if (result.code() == Result::Succeeded) {
            emit loaded(QString::fromUtf8(request->secret().data()));
            return;
        }

        // Nothing stored yet is the normal state before the first sign in.
        if (result.errorCode() == Result::InvalidSecretError
                || result.errorCode() == Result::InvalidSecretIdentifierError) {
            emit loaded(QString());
            return;
        }

        emit failed(result.errorMessage());
        emit loaded(QString());
    });
}

void SecretsStore::save(const QString &token)
{
    // Sailfish Secrets has no way to replace a secret: storing over one that is
    // already there is refused. So the old one goes first, and how that went is
    // of no interest, since having nothing stored is the normal state before
    // the first sign in.
    DeleteSecretRequest *request = new DeleteSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(identifier());
    request->setUserInteractionMode(SecretManager::PreventInteraction);

    run(request, [this, token](DeleteSecretRequest *) { store(token); });
}

void SecretsStore::store(const QString &token)
{
    Secret secret(identifier());
    secret.setType(Secret::TypeBlob);
    secret.setData(token.toUtf8());

    StoreSecretRequest *request = new StoreSecretRequest(this);
    request->setManager(&m_manager);
    request->setSecretStorageType(StoreSecretRequest::StandaloneDeviceLockSecret);
    request->setDeviceLockUnlockSemantic(SecretManager::DeviceLockKeepUnlocked);
    request->setAccessControlMode(SecretManager::OwnerOnlyMode);
    request->setEncryptionPluginName(SecretManager::DefaultEncryptionPluginName);
    request->setUserInteractionMode(SecretManager::PreventInteraction);
    request->setSecret(secret);

    run(request, [this](StoreSecretRequest *request) {
        const Result result = request->result();
        if (result.code() != Result::Succeeded)
            emit failed(result.errorMessage());
    });
}

void SecretsStore::remove()
{
    DeleteSecretRequest *request = new DeleteSecretRequest(this);
    request->setManager(&m_manager);
    request->setIdentifier(identifier());
    request->setUserInteractionMode(SecretManager::PreventInteraction);

    run(request, [](DeleteSecretRequest *) {});
}
