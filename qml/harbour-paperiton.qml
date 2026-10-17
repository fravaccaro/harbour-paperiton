import Nemo.Notifications 1.0
import Opal.SupportMe 1.0
import QtQuick 2.0
import Sailfish.Share 1.0
import Sailfish.Silica 1.0
import "components"
import "pages"

ApplicationWindow {
    id: app

    // Files handed over by another app, until this app is in a state to show
    // them: signed in, and not in the middle of a page transition.
    property var pendingFiles: []
    // Whether the page for adding files has been asked for at all. The cover
    // action asks for it without bringing any files along.
    property bool uploadWanted: false
    // Kept so that an upload run which added a single file can name it, the way
    // each upload used to be announced.
    property string lastAddedFileName

    // Documents asked for from the list are written to Downloads/Paperiton one
    // after another. The run lives here rather than on the page that started it,
    // so leaving that page does not take the run, or its notification, with it.
    property var downloadIds: []
    property int downloadIndex: -1
    property int downloadOk: 0
    property int downloadFail: 0
    property string downloadFileName
    // How much of the file being fetched has arrived, as far as the server said.
    property real downloadByteProgress: 0
    readonly property bool downloading: downloadIndex >= 0
    // The whole run, so the bar fills across all of the files rather than
    // starting over at each of them.
    readonly property real downloadProgress: {
        if (downloadIds.length === 0)
            return 0;

        return Math.min((downloadIndex + downloadByteProgress) / downloadIds.length, 1);
    }

    function downloadDocuments(ids) {
        if (downloading || !ids || ids.length === 0)
            return ;

        downloadIds = ids.slice();
        downloadIndex = -1;
        downloadOk = 0;
        downloadFail = 0;
        nextDownload();
    }

    function nextDownload() {
        var next = downloadIndex + 1;
        if (next >= downloadIds.length) {
            var total = downloadIds.length;
            var saved = downloadOk;
            var failed = downloadFail;
            downloadIndex = -1;
            downloadIds = [];
            downloadFileName = "";
            downloadNotice.close();
            if (failed === 0) {
                if (total === 1)
                    notify(qsTr("The file was saved in Downloads/Paperiton"));
                else
                    notify(qsTr("%1 files were saved in Downloads/Paperiton").arg(saved));
            } else if (saved === 0) {
                notify(total === 1 ? qsTr("Could not download the file") : qsTr("Could not download the files"));
            } else {
                notify(qsTr("%1 of %2 files were saved in Downloads/Paperiton").arg(saved).arg(total));
            }
            return ;
        }

        var id = downloadIds[next];
        var row = documentRow(id);
        var originalName = row ? (row.originalFileName || "") : "";
        var archivedName = row ? (row.archivedFileName || "") : "";
        var title = row ? (row.title || "") : "";
        // The same choice a single Open makes: an image as it was uploaded,
        // everything else from the archived PDF when the server has one.
        var isImage = /\.(png|jpe?g|gif|webp|bmp|tiff?)$/i.test(originalName);
        var original = isImage || archivedName === "";
        var name = original ? (originalName || archivedName) : (archivedName || originalName);
        if (!name)
            name = (title !== "" ? title : ("paperless-" + id)) + ".pdf";

        // The name is in place before the run counts as started, so the first
        // notification the timer publishes already says which file it is about.
        downloadFileName = name;
        downloadByteProgress = 0;
        downloadIndex = next;
        Paperless.saveDocument(id, name, original);
    }

    function documentRow(documentId) {
        for (var i = 0; i < Documents.count; ++i) {
            var row = Documents.get(i);
            if (row.documentId === documentId)
                return row;
        }
        return null;
    }

    function showMain() {
        pageStack.replaceAbove(null, Paperless.authenticated ? documentsPage : loginPage);
        takePendingUpload();
    }

    // Until the server has answered which operations the account may perform,
    // everything is offered and the server stays the authority.
    function allowed(permission) {
        return !Paperless.permissionsKnown || Paperless.can(permission);
    }

    // Adding files can be asked for from outside the pages: another app sharing
    // them, or the cover action. Both may arrive before the app has a page to
    // put in front of anyone, so both wait in the same place.
    function openUpload(files) {
        activate();
        if (files !== undefined && files.length > 0)
            pendingFiles = files;

        uploadWanted = true;
        takePendingUpload();
    }

    function takePendingUpload() {
        if (!uploadWanted || !Settings.ready || !Paperless.authenticated)
            return ;

        // A share that starts the app arrives while the first page is still
        // animating in, and a push during a transition is refused, which used to
        // lose the file. So it waits for the stack to settle.
        if (pageStack.busy) {
            uploadRetry.restart();
            return ;
        }
        // The page may already be open, from an earlier share or from the last
        // time the cover action was used, and a second copy of it would only
        // hide the first. A share still opens its own, since it carries files
        // the open page was not asked about.
        var open = pageStack.find(function(item) {
            return item.objectName === "uploadPage";
        });
        if (open && pendingFiles.length === 0) {
            uploadWanted = false;
            pageStack.pop(open, PageStackAction.Immediate);
            return ;
        }
        var files = pendingFiles;
        pendingFiles = [];
        uploadWanted = false;
        pageStack.push(Qt.resolvedUrl("pages/UploadPage.qml"), {
            "filePaths": files
        });
    }

    // Signing out has to leave every page that shows the archive behind. The
    // remorse runs its callback right away when the page starts deactivating, so
    // the request can arrive in the middle of a page change, which the stack
    // refuses. Hence it is taken on a later pass of the event loop, and again
    // until the stack is idle.
    function showLogin() {
        loginNavigation.restart();
    }

    // Work that finishes away from the page in front of the user. A notice is
    // drawn inside the window, so it only reaches someone who is looking at the
    // app; from the cover or the background the notification area does.
    function notify(text) {
        if (app.applicationActive) {
            Notices.show(text, Notice.Short);
            return ;
        }
        backgroundNotice.previewBody = text;
        backgroundNotice.publish();
    }

    initialPage: Settings.ready ? (Paperless.authenticated ? documentsPage : loginPage) : startPage
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    Timer {
        id: uploadRetry

        interval: 200
        onTriggered: app.takePendingUpload()
    }

    Timer {
        id: loginNavigation

        interval: 100
        onTriggered: {
            if (pageStack.busy)
                restart();
            else
                pageStack.replaceAbove(null, loginPage);
        }
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
            uploadNotice.body = Uploads.runTotal > 1 ? qsTr("%1 (%2 of %3)").arg(Uploads.currentFileName).arg(Math.min(Uploads.runDone + 1, Uploads.runTotal)).arg(Uploads.runTotal) : Uploads.currentFileName;
            uploadNotice.progress = Uploads.progress;
            uploadNotice.publish();
        }
    }

    // A download run is followed the same way an upload run is: one notification
    // with a bar that fills as the files arrive, and a summary once it is over.
    Notification {
        id: downloadNotice

        isTransient: false
        urgency: Notification.Low
        summary: qsTr("Downloading from Paperless")
    }

    Timer {
        running: app.downloading
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            downloadNotice.body = app.downloadIds.length > 1 ? qsTr("%1 (%2 of %3)").arg(app.downloadFileName).arg(Math.min(app.downloadIndex + 1, app.downloadIds.length)).arg(app.downloadIds.length) : app.downloadFileName;
            downloadNotice.progress = app.downloadProgress;
            downloadNotice.publish();
        }
    }

    Connections {
        target: Paperless
        // A server that does not say how long the file is leaves the bar where
        // it stands, rather than sending it back to the start of the file.
        onDocumentSaveProgress: {
            if (!app.downloading || total <= 0 || documentId !== app.downloadIds[app.downloadIndex])
                return ;

            app.downloadByteProgress = Math.min(received / total, 1);
        }
        onDocumentSaved: {
            if (!app.downloading || documentId !== app.downloadIds[app.downloadIndex])
                return ;

            app.downloadOk++;
            app.nextDownload();
        }
        onDocumentSaveFailed: {
            if (!app.downloading || documentId !== app.downloadIds[app.downloadIndex])
                return ;

            app.downloadFail++;
            app.nextDownload();
        }
    }

    Connections {
        target: Uploads
        onUploadCompleted: app.lastAddedFileName = fileName
        // A file that could not be uploaded is reported on its own, since it
        // names the file and what the server said about it.
        onUploadFailed: app.notify(qsTr("%1 could not be uploaded").arg(fileName))
        onRunFinished: {
            uploadNotice.close();
            if (added === 1)
                app.notify(qsTr("%1 was added to the archive").arg(app.lastAddedFileName));
            else if (added > 1)
                app.notify(qsTr("%1 files were added to the archive").arg(added));
        }
    }

    Component {
        id: startPage

        StartPage {
        }

    }

    Component {
        id: documentsPage

        DocumentsPage {
        }

    }

    Component {
        id: loginPage

        LoginPage {
        }

    }

    Connections {
        target: Settings
        onReadyChanged: {
            if (Settings.ready)
                app.showMain();

        }
    }

    Connections {
        target: Paperless
        onAuthenticatedChanged: {
            if (Paperless.authenticated)
                app.takePendingUpload();
            else
                app.showLogin();
        }
    }

    // Asks for support once the app has been used for a while, and not again
    // for a long time after the answer.
    AskForSupport {

        contents: Component {
            PaperitonSupportDialog {
            }

        }

    }

    ShareProvider {
        method: "upload"
        registerName: true
        // The kinds of file Paperless takes, from the one list the app keeps of
        // them. The share method in the desktop file names the same kinds: that
        // is what other apps read before the app is running.
        capabilities: Uploads.acceptedMimeTypes
        onTriggered: {
            // A share can also carry plain text rather than a file; this app is
            // offered for files, and only a file has a path to read.
            var files = [];
            for (var i = 0; i < resources.length; ++i) {
                if (resources[i].type === ShareResource.FilePathType)
                    files.push(resources[i].filePath);

            }
            if (files.length === 0)
                return ;

            app.openUpload(files);
        }
    }

}
