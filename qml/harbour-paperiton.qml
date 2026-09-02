import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import Nemo.Notifications 1.0
import Opal.SupportMe 1.0
import "components"
import "pages"

ApplicationWindow {
    id: app

    // Files handed over by another app, until this app is in a state to show
    // them: signed in, and not in the middle of a page transition.
    property var pendingShare: []

    // Kept so that an upload run which added a single file can name it, the way
    // each upload used to be announced.
    property string lastAddedFileName

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

    // An upload keeps going once the page that started it is gone, so it is
    // followed in the notification area, with a bar that fills as the run
    // advances and a summary once it is over.
    Notification {
        id: uploadNotice

        isTransient: false
        urgency: Notification.Low
        summary: qsTr("Adding to Paperless")
    }

    // The byte callbacks arrive many times a second, so the notification is
    // republished on a timer rather than on every change.
    Timer {
        running: Uploads.activeCount > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            uploadNotice.body = Uploads.runTotal > 1
                    ? qsTr("%1 (%2 of %3)").arg(Uploads.currentFileName)
                                           .arg(Math.min(Uploads.runDone + 1, Uploads.runTotal))
                                           .arg(Uploads.runTotal)
                    : Uploads.currentFileName
            uploadNotice.progress = Uploads.progress
            uploadNotice.publish()
        }
    }

    Connections {
        target: Uploads
        onUploadCompleted: app.lastAddedFileName = fileName
        // A file that could not be uploaded is reported on its own, since it
        // names the file and what the server said about it.
        onUploadFailed: app.notify(qsTr("%1 could not be uploaded").arg(fileName))
        onRunFinished: {
            uploadNotice.close()

            if (added === 1)
                app.notify(qsTr("%1 was added to the archive").arg(app.lastAddedFileName))
            else if (added > 1)
                app.notify(qsTr("%1 files were added to the archive").arg(added))
        }
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

    // Asks for support once the app has been used for a while, and not again
    // for a long time after the answer.
    AskForSupport {
        contents: Component {
            PaperitonSupportDialog {}
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
