import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import Nemo.Notifications 1.0
import "pages"

ApplicationWindow {
    id: app

    // Files handed over by another app, until this app is in a state to show
    // them: signed in, and not in the middle of a page transition.
    property var pendingShare: []

    initialPage: Settings.ready ? (Paperless.authenticated ? documentsPage : loginPage) : startPage
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    function showMain() {
        pageStack.replaceAbove(null, Paperless.authenticated ? documentsPage : loginPage)
        takePendingShare()
    }

    // Until the server has answered which operations the account may perform,
    // everything is offered and the server stays the authority.
    function allowed(permission) {
        return !Paperless.permissionsKnown || Paperless.can(permission)
    }

    function takePendingShare() {
        if (pendingShare.length === 0 || !Settings.ready || !Paperless.authenticated)
            return

        // A share that starts the app arrives while the first page is still
        // animating in, and a push during a transition is refused, which used to
        // lose the file. So it waits for the stack to settle.
        if (pageStack.busy) {
            shareRetry.restart()
            return
        }

        var files = pendingShare
        pendingShare = []
        pageStack.push(Qt.resolvedUrl("pages/UploadPage.qml"), { filePaths: files })
    }

    Timer {
        id: shareRetry
        interval: 200
        onTriggered: app.takePendingShare()
    }

    // Work that finishes away from the page in front of the user. A notice is
    // drawn inside the window, so it only reaches someone who is looking at the
    // app; from the cover or the background the notification area does.
    function notify(text) {
        if (app.applicationActive) {
            Notices.show(text, Notice.Short)
            return
        }

        backgroundNotice.previewBody = text
        backgroundNotice.publish()
    }

    Notification {
        id: backgroundNotice

        isTransient: true
        urgency: Notification.Low
        previewSummary: qsTr("Paperiton")
    }

    Connections {
        target: Uploads
        onUploadCompleted: app.notify(qsTr("%1 was added to the archive").arg(fileName))
        onUploadFailed: app.notify(qsTr("%1 could not be uploaded").arg(fileName))
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
            if (Paperless.authenticated)
                app.takePendingShare()
            else
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
            app.pendingShare = files
            app.takePendingShare()
        }
    }
}
