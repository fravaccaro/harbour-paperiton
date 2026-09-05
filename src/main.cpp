#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <QGuiApplication>
#include <QLocale>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QScopedPointer>
#include <QTranslator>
#include <QtQml>

#include <sailfishapp.h>

#include "paperless/api.h"
#include "paperless/config.h"
#include "paperless/customfieldsmodel.h"
#include "paperless/documentlistmodel.h"
#include "paperless/lookupmodel.h"
#include "paperless/savedviewmodel.h"
#include "paperless/tasklistmodel.h"
#include "paperless/thumbimageprovider.h"
#include "paperless/uploadqueue.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    // Must be set before anything resolves QStandardPaths, so that settings and
    // caches land in the directories Sailjail whitelists for this app.
    app->setOrganizationName(QStringLiteral("org.frapps.paperiton"));
    app->setOrganizationDomain(QStringLiteral("frapps.org"));
    app->setApplicationName(QStringLiteral("harbour-paperiton"));
    app->setApplicationVersion(QStringLiteral(APP_VERSION));

    // The interface follows the device language; without a catalogue for it the
    // sources' English is used.
    QScopedPointer<QTranslator> translator(new QTranslator);
    if (translator->load(QLocale(), QStringLiteral("harbour-paperiton"), QStringLiteral("-"),
                         SailfishApp::pathTo(QStringLiteral("translations")).toLocalFile())) {
        app->installTranslator(translator.data());
    }

    Config config;
    PaperlessApi api(&config);

    // Document copies and camera captures are scratch files: they go when the
    // app quits, and leftovers of a run that was killed go at the next start.
    api.clearTransientCache();
    QObject::connect(app.data(), &QGuiApplication::aboutToQuit,
                     &api, &PaperlessApi::clearTransientCache);

    LookupModel tags(&api, QStringLiteral("tags"));
    LookupModel correspondents(&api, QStringLiteral("correspondents"));
    LookupModel documentTypes(&api, QStringLiteral("document_types"));
    CustomFieldsModel customFields(&api);
    SavedViewModel savedViews(&api);
    TaskListModel tasks(&api);
    UploadQueue uploads(&api);
    ThumbnailFetcher thumbnailFetcher(&api);

    // One list for the whole app: the list page and the filter page work on the
    // same documents, and nothing else pages the archive on the side.
    DocumentListModel documents(&api);

    qmlRegisterUncreatableType<UploadQueue>("harbour.paperiton", 1, 0, "UploadQueue",
                                            QStringLiteral("Provided as the Uploads context property"));

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->engine()->addImageProvider(QStringLiteral("paperless"),
                                     new ThumbImageProvider(&thumbnailFetcher));

    // The Opal modules are shipped with the application rather than installed
    // system-wide, so the engine has to be told where to look for them.
    view->engine()->addImportPath(SailfishApp::pathTo(QStringLiteral("qml/modules")).toString());

    QQmlContext *context = view->rootContext();
    context->setContextProperty(QStringLiteral("Paperless"), &api);
    context->setContextProperty(QStringLiteral("Settings"), &config);
    context->setContextProperty(QStringLiteral("Documents"), &documents);
    context->setContextProperty(QStringLiteral("Tags"), &tags);
    context->setContextProperty(QStringLiteral("Correspondents"), &correspondents);
    context->setContextProperty(QStringLiteral("DocumentTypes"), &documentTypes);
    context->setContextProperty(QStringLiteral("CustomFields"), &customFields);
    context->setContextProperty(QStringLiteral("SavedViews"), &savedViews);
    context->setContextProperty(QStringLiteral("Tasks"), &tasks);
    context->setContextProperty(QStringLiteral("Uploads"), &uploads);

    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/harbour-paperiton.qml")));
    view->show();

    return app->exec();
}
