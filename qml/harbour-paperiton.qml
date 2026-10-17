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

    // What a caller already knows about a document, by id, so that a page which
    // has the document itself does not depend on the list holding its row.
    property var downloadChoices: ({
    })
    // Finished download notices, one per file, kept until the user dismisses
    // them so Open and Share still reach the handlers that published them.
    property var downloadNotices: []

    function downloadDocuments(ids) {
        startDownload(ids, ({
        }));
    }

    function downloadDocument(documentId, fileName, original) {
        var choices = {
        };
        choices[documentId] = {
            "fileName": fileName,
            "original": original
        };
        startDownload([documentId], choices);
    }

    function startDownload(ids, choices) {
        if (downloading || !ids || ids.length === 0)
            return ;

        downloadIds = ids.slice();
        downloadChoices = choices;
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
            // Each successful file already has its own notice. Only a failure
            // still needs something said here.
            if (failed > 0) {
                if (saved === 0)
                    notify(total === 1 ? qsTr("Could not download the file") : qsTr("Could not download the files"));
                else
                    notify(qsTr("%1 of %2 files were saved in Downloads/Paperiton").arg(saved).arg(total));
            }
            return ;
        }

        var id = downloadIds[next];
        var name;
        var original;
        var chosen = downloadChoices[id];
        if (chosen) {
            name = chosen.fileName;
            original = chosen.original;
        } else {
            var row = documentRow(id);
            var originalName = row ? (row.originalFileName || "") : "";
            var archivedName = row ? (row.archivedFileName || "") : "";
            var title = row ? (row.title || "") : "";
            // The same choice a single Open makes: an image as it was uploaded,
            // everything else from the archived PDF when the server has one.
            var isImage = /\.(png|jpe?g|gif|webp|bmp|tiff?)$/i.test(originalName);
            original = isImage || archivedName === "";
            name = original ? (originalName || archivedName) : (archivedName || originalName);
            if (!name)
                name = (title !== "" ? title : ("paperless-" + id)) + ".pdf";
        }

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

    function baseName(path) {
        var slash = String(path).lastIndexOf("/");
        return slash >= 0 ? String(path).substring(slash + 1) : String(path);
    }

    function isImagePath(path) {
        return /\.(png|jpe?g|gif|webp|bmp|tiff?)$/i.test(String(path));
    }

    function mimeForPath(path) {
        var name = String(path).toLowerCase();
        if (/\.pdf$/.test(name))
            return "application/pdf";
        if (/\.png$/.test(name))
            return "image/png";
        if (/\.jpe?g$/.test(name))
            return "image/jpeg";
        if (/\.gif$/.test(name))
            return "image/gif";
        if (/\.webp$/.test(name))
            return "image/webp";
        if (/\.tiff?$/.test(name))
            return "image/tiff";
        if (/\.bmp$/.test(name))
            return "image/bmp";
        if (/\.txt$/.test(name))
            return "text/plain";
        return "application/octet-stream";
    }

    // Same choice a preview Open makes once the file is already on disk.
    function openDownloaded(path) {
        activate();
        if (isImagePath(path)) {
            pageStack.push(Qt.resolvedUrl("pages/ImageViewPage.qml"), {
                "source": Paperless.fileUrl(path),
                "title": baseName(path)
            });
            return ;
        }
        Qt.openUrlExternally(Paperless.fileUrl(path));
    }

    function shareDownloaded(path) {
        activate();
        downloadShare.mimeType = mimeForPath(path);
        downloadShare.resources = [path];
        downloadShare.trigger();
    }

    // One events-view entry per successful file, with Open (and body click)
    // and Share, the way a camera app keeps a notice for the last capture.
    function publishDownloadedNotice(filePath) {
        var notice = downloadedNoticeComponent.createObject(app, {
            "filePath": filePath
        });
        if (!notice)
            return ;

        var kept = downloadNotices.slice();
        kept.push(notice);
        downloadNotices = kept;
        notice.summary = qsTr("Downloaded");
        notice.body = baseName(filePath);
        notice.previewSummary = qsTr("Downloaded");
        notice.previewBody = baseName(filePath);
        notice.publish();
    }

    function forgetDownloadNotice(notice) {
        var kept = [];
        for (var i = 0; i < downloadNotices.length; ++i) {
            if (downloadNotices[i] !== notice)
                kept.push(downloadNotices[i]);
        }
        downloadNotices = kept;
        notice.destroy();
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

    // The smaller things that happen along the way: a notice drawn inside the
    // window, so it only reaches someone who is looking at the app; from the
    // cover or the background a banner that is gone once it has been read.
    function notify(text) {
        if (app.applicationActive) {
            Notices.show(text, Notice.Short);
            return ;
        }
        backgroundNotice.previewBody = text;
        backgroundNotice.publish();
    }

    // A run that moves files is work the user should be able to find again
    // later, so it keeps one notification in the events view throughout: while
    // it runs this says which file it is on and how far along it is, with no
    // banner, since the run announces itself once at the end rather than every
    // second.
    function noticeRunning(notice, summary, body, progress) {
        notice.summary = summary;
        notice.body = body;
        notice.progress = progress;
        notice.previewSummary = "";
        notice.previewBody = "";
        notice.publish();
    }

    // The run is over: the bar goes, what it achieved stays in the events view,
    // and this one publish is the only one that asks for a banner.
    function noticeFinished(notice, summary, body) {
        notice.summary = summary;
        notice.body = body;
        notice.progress = undefined;
        notice.previewSummary = summary;
        notice.previewBody = body;
        notice.publish();
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

        appName: "Paperiton"
        appIcon: "harbour-paperiton"
        isTransient: true
        urgency: Notification.Low
        previewSummary: qsTr("Paperiton")
    }

    // An upload keeps going once the page that started it is gone, so it is
    // followed in the notification area, with a bar that fills as the run
    // advances and a summary that stays once it is over.
    // The events view groups what it shows by the name of the app it came from,
    // and drops a notification that does not name one, so both of these say who
    // they are about.
    Notification {
        id: uploadNotice

        appName: "Paperiton"
        appIcon: "harbour-paperiton"
        isTransient: false
        urgency: Notification.Normal
    }

    // The byte callbacks arrive many times a second, so the notification is
    // republished on a timer rather than on every change.
    Timer {
        running: Uploads.activeCount > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            app.noticeRunning(uploadNotice, qsTr("Adding to Paperless"), Uploads.runTotal > 1 ? qsTr("%1 (%2 of %3)").arg(Uploads.currentFileName).arg(Math.min(Uploads.runDone + 1, Uploads.runTotal)).arg(Uploads.runTotal) : Uploads.currentFileName, Uploads.progress);
        }
    }

    // Progress only: each finished file gets a notice of its own below.
    Notification {
        id: downloadNotice

        appName: "Paperiton"
        appIcon: "harbour-paperiton"
        isTransient: false
        urgency: Notification.Normal
    }

    Timer {
        running: app.downloading
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            app.noticeRunning(downloadNotice, qsTr("Downloading"), app.downloadIds.length > 1 ? qsTr("%1 (%2 of %3)").arg(app.downloadFileName).arg(Math.min(app.downloadIndex + 1, app.downloadIds.length)).arg(app.downloadIds.length) : app.downloadFileName, app.downloadProgress);
        }
    }

    ShareAction {
        id: downloadShare
    }

    Component {
        id: downloadedNoticeComponent

        Notification {
            id: notice

            property string filePath

            appName: "Paperiton"
            appIcon: "harbour-paperiton"
            isTransient: false
            urgency: Notification.Normal
            // default and open both open the file; share has no remote service
            // of its own and is taken in onActionInvoked, as Tarkka does.
            remoteActions: [{
                    "name": "default"
                }, {
                    "name": "share",
                    "displayName": qsTr("Share"),
                    "icon": "icon-s-share"
                }, {
                    "name": "open",
                    "displayName": qsTr("Open")
                }]
            onClicked: app.openDownloaded(filePath)
            onActionInvoked: {
                if (name === "open" || name === "default")
                    app.openDownloaded(filePath);
                else if (name === "share")
                    app.shareDownloaded(filePath);
            }
            onClosed: app.forgetDownloadNotice(notice)
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
            app.publishDownloadedNotice(filePath);
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
            var outcome;
            if (added === 1)
                outcome = qsTr("%1 was added to the archive").arg(app.lastAddedFileName);
            else if (added > 1)
                outcome = qsTr("%1 files were added to the archive").arg(added);
            else
                outcome = qsTr("Nothing was added to the archive");
            app.noticeFinished(uploadNotice, qsTr("Added to Paperless"), outcome);
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
