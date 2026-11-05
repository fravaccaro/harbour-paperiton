import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    // The server counts the documents under each tag itself, so the number is
    // read off the inbox tag rather than by listing the inbox a second time.
    readonly property int inboxCount: Paperless.authenticated ? Tags.inboxDocumentCount : 0
    readonly property bool uploading: Uploads.activeCount > 0
    // A run of uploads is the one thing happening rather than a count that
    // keeps, so it has the cover to itself while it lasts.
    readonly property bool showCounts: Paperless.authenticated && !uploading
    // Not every server defines an inbox tag, and a count of one that is not
    // there would be a nought standing for nothing.
    readonly property bool showInbox: showCounts && Tags.inboxTagId > 0

    clip: true

    HighlightImage {
        source: Qt.resolvedUrl("cover-boat.png")
        color: Theme.primaryColor
        // The boat is wider than it is tall, so its width is what decides how
        // much of the cover it takes.
        sourceSize.width: cover.width * 0.85
        // The same alpha reads much heavier as a dark glyph on a light ambience.
        opacity: Theme.colorScheme === Theme.LightOnDark ? 0.13 : 0.08

        // Only the stern and the keel are cut off: the hull is what makes the
        // shape readable, so it stays almost whole, afloat in the corner.
        anchors {
            right: parent.right
            rightMargin: -width * 0.08
            bottom: parent.bottom
            bottomMargin: -height * 0.04
        }

    }

    Column {
        spacing: Theme.paddingMedium

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.paddingMedium
        }

        // A number and the word for what it counts belong together, so each
        // pair is a column of its own and the spacing above separates them.
        Column {
            width: parent.width
            visible: cover.uploading

            CoverCount {
                text: Uploads.activeCount
            }

            CoverCaption {
                text: qsTr("uploading", "goes under the number of files being uploaded")
            }

        }

        Column {
            width: parent.width
            visible: cover.showInbox

            CoverCount {
                text: cover.inboxCount
            }

            CoverCaption {
                text: qsTr("in inbox", "goes under the number of documents in the inbox")
            }

        }

        Column {
            width: parent.width
            visible: cover.showCounts

            CoverCount {
                text: Paperless.totalDocuments
            }

            CoverCaption {
                text: qsTr("documents", "goes under the total number of documents")
            }

        }

        CoverCaption {
            visible: !Paperless.authenticated
            text: qsTr("Not signed in")
        }

    }

    BusyIndicator {
        size: BusyIndicatorSize.Small
        running: cover.uploading

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge
        }

    }

    // Offered only to someone who could act on it: signed in, and allowed by the
    // server to add documents, which is the rule the pulley menu follows too.
    CoverActionList {
        enabled: Paperless.authenticated && __silica_applicationwindow_instance.allowed("add_document")

        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            // The cover is loaded outside the window's own file, so the window
            // is reached by the name Silica gives it.
            onTriggered: __silica_applicationwindow_instance.openUpload()
        }

    }

    // The number shown here is the one from the last time the tags were read,
    // so leaving the app is the moment to ask for them again.
    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active && Paperless.authenticated)
                Tags.reloadIfStale(120);

        }
    }

}
