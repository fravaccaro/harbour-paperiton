TARGET = harbour-paperiton

CONFIG += sailfishapp sailfishapp_i18n c++11
QT += network

# sailfishapp.prf pulls in link_pkgconfig and resolves PKGCONFIG afterwards, so
# requesting link_pkgconfig here instead would drop -lsailfishapp from the link.
PKGCONFIG += sailfishsecrets

INCLUDEPATH += $$PWD/src

# Autocompletion for the Opal modules bundled under qml/modules. They install
# with the rest of the qml tree; main.cpp adds the matching runtime import path.
QML_IMPORT_PATH += qml/modules

# The packaged version, so that the About page cannot drift from what was built.
# Building outside the spec still has to produce something, hence the fallback.
isEmpty(APP_VERSION): APP_VERSION = 0.0-devel
DEFINES += APP_VERSION=\\\"$$APP_VERSION\\\"

CONFIG(debug, debug|release): DEFINES += QT_QML_DEBUG

SOURCES += \
    src/main.cpp \
    src/paperless/api.cpp \
    src/paperless/config.cpp \
    src/paperless/customfieldsmodel.cpp \
    src/paperless/documentlistmodel.cpp \
    src/paperless/lookupmodel.cpp \
    src/paperless/savedviewmodel.cpp \
    src/paperless/secretsstore.cpp \
    src/paperless/tasklistmodel.cpp \
    src/paperless/thumbimageprovider.cpp \
    src/paperless/uploadqueue.cpp

HEADERS += \
    src/paperless/api.h \
    src/paperless/config.h \
    src/paperless/customfieldsmodel.h \
    src/paperless/documentlistmodel.h \
    src/paperless/filetypes.h \
    src/paperless/lookupmodel.h \
    src/paperless/savedviewmodel.h \
    src/paperless/secretsstore.h \
    src/paperless/staleness.h \
    src/paperless/taskfields.h \
    src/paperless/tasklistmodel.h \
    src/paperless/thumbimageprovider.h \
    src/paperless/uploadqueue.h

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172 256x256

# Shown on the About page. The launcher sizes above are installed into hicolor
# by sailfishapp.prf; this one only has to reach the app's own data directory.
appicon.files = icons/appicon.png
appicon.path = /usr/share/$${TARGET}
INSTALLS += appicon

# Only the translated catalogues belong here. The English source strings live in
# translations/harbour-paperiton.ts, which sailfishapp_i18n refreshes on its own.
TRANSLATIONS += \
    translations/harbour-paperiton-it.ts

DISTFILES += \
    harbour-paperiton.desktop \
    qml/harbour-paperiton.qml \
    qml/components/PaperitonSupportDialog.qml \
    qml/cover/CoverPage.qml \
    qml/cover/cover-doc.png \
    qml/pages/AboutPage.qml \
    qml/pages/BulkEditPage.qml \
    qml/pages/CameraPage.qml \
    qml/pages/DocumentEditPage.qml \
    qml/pages/DocumentPage.qml \
    qml/pages/DocumentsPage.qml \
    qml/pages/FilterPage.qml \
    qml/pages/ImageViewPage.qml \
    qml/pages/LoginPage.qml \
    qml/pages/LookupPickerPage.qml \
    qml/pages/NotesPage.qml \
    qml/pages/PdfViewPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/StartPage.qml \
    qml/pages/TasksPage.qml \
    qml/pages/TranslationsPage.qml \
    qml/pages/UploadPage.qml \
    qml/pages/WebLoginPage.qml \
    translations/harbour-paperiton.ts
