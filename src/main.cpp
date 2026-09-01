#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QScopedPointer>
#include <QtQml>

#include <sailfishapp.h>

#include "paperless/api.h"
#include "paperless/config.h"
#include "paperless/documentlistmodel.h"
#include "paperless/lookupmodel.h"
#include "paperless/thumbimageprovider.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    // Must be set before anything resolves QStandardPaths, so that settings and
    // caches land in the directories Sailjail whitelists for this app.
    app->setOrganizationName(QStringLiteral("org.fravaccaro"));
    app->setOrganizationDomain(QStringLiteral("fravaccaro.org"));
    app->setApplicationName(QStringLiteral("harbour-paperiton"));
    app->setApplicationVersion(QStringLiteral("0.1"));

    Config config;
    PaperlessApi api(&config);
    LookupModel tags(&api, QStringLiteral("tags"));
    LookupModel correspondents(&api, QStringLiteral("correspondents"));
    LookupModel documentTypes(&api, QStringLiteral("document_types"));
    ThumbnailFetcher thumbnailFetcher(&api);

    DocumentListModel::setApi(&api);
    qmlRegisterType<DocumentListModel>("harbour.paperiton", 1, 0, "DocumentListModel");

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->engine()->addImageProvider(QStringLiteral("paperless"),
                                     new ThumbImageProvider(&thumbnailFetcher));

    QQmlContext *context = view->rootContext();
    context->setContextProperty(QStringLiteral("Paperless"), &api);
    context->setContextProperty(QStringLiteral("Settings"), &config);
    context->setContextProperty(QStringLiteral("Tags"), &tags);
    context->setContextProperty(QStringLiteral("Correspondents"), &correspondents);
    context->setContextProperty(QStringLiteral("DocumentTypes"), &documentTypes);

    if (api.isAuthenticated()) {
        tags.reload();
        correspondents.reload();
        documentTypes.reload();
    }

    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/harbour-paperiton.qml")));
    view->show();

    return app->exec();
}
