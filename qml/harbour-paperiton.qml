import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import "pages"

ApplicationWindow {
    id: app

    // Files handed over by another app while Paperiton was signed out.
    property var pendingShare: []

    initialPage: Settings.ready ? (Paperless.authenticated ? documentsPage : loginPage) : startPage
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    function showMain() {
        pageStack.replaceAbove(null, Paperless.authenticated ? documentsPage : loginPage)
        if (Paperless.authenticated)
            takePendingShare()
    }

    // Until the server has answered which operations the account may perform,
    // everything is offered and the server stays the authority.
    function allowed(permission) {
        return !Paperless.permissionsKnown || Paperless.can(permission)
    }

    function takePendingShare() {
        if (pendingShare.length === 0)
            return

        var files = pendingShare
        pendingShare = []
        pageStack.push(Qt.resolvedUrl("pages/UploadPage.qml"), { filePaths: files })
    }

    Component {
        id: startPage
        StartPage {}
    }

    Component {
        id: documentsPage
        DocumentsPage {}
    }

    Component {
        id: loginPage
        LoginPage {}
    }

    Connections {
        target: Settings
        onReadyChanged: {
            if (Settings.ready)
                app.showMain()
        }
    }

    Connections {
        target: Paperless
        onAuthenticatedChanged: {
            if (!Paperless.authenticated)
                pageStack.replaceAbove(null, loginPage)
        }
    }

    ShareProvider {
        method: "upload"
        registerName: true
        capabilities: ["application/pdf", "image/*", "text/plain", "application/*"]

        onTriggered: {
            var files = []
            for (var i = 0; i < resources.length; ++i) {
                var path = resources[i].filePath
                if (path)
                    files.push(path)
            }

            if (files.length === 0)
                return

            app.activate()

            if (Paperless.authenticated && Settings.ready)
                pageStack.push(Qt.resolvedUrl("pages/UploadPage.qml"), { filePaths: files })
            else
                app.pendingShare = files
        }
    }
}
