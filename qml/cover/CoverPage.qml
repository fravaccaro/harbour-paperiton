import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    // The server counts the documents under each tag itself, so the number is
    // read off the inbox tag rather than by listing the inbox a second time.
    readonly property int inboxCount: Paperless.authenticated ? Tags.inboxDocumentCount : 0
    readonly property bool uploading: Uploads.activeCount > 0
    readonly property bool showInbox: !uploading && inboxCount > 0
    readonly property int headline: uploading ? Uploads.activeCount : showInbox ? inboxCount : Paperless.totalDocuments

    clip: true

    HighlightImage {
        source: Qt.resolvedUrl("cover-doc.png")
        color: Theme.primaryColor
        // The sheet is taller than it is wide, so its height is what decides
        // how much of the cover it takes.
        sourceSize.height: cover.height * 0.65
        // The same alpha reads much heavier as a dark glyph on a light ambience.
        opacity: Theme.colorScheme === Theme.LightOnDark ? 0.13 : 0.08

        anchors {
            right: parent.right
            rightMargin: -width * 0.22
            bottom: parent.bottom
            bottomMargin: -height * 0.22
        }

    }

    Column {
        spacing: Theme.paddingSmall

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.paddingMedium
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Paperiton")
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeSmall
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: Paperless.authenticated && cover.headline > 0
            text: cover.headline
            color: Theme.highlightColor

            font {
                pixelSize: Theme.fontSizeHuge
                family: Theme.fontFamilyHeading
            }

        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeExtraSmall
            text: {
                if (!Paperless.authenticated)
                    return qsTr("Not signed in");

                if (cover.uploading)
                    return qsTr("uploading", "goes under the number of files being uploaded");

                if (cover.showInbox)
                    return qsTr("in inbox", "goes under the number of documents in the inbox");

                if (Paperless.totalDocuments === 0)
                    return qsTr("No documents yet");

                return qsTr("documents", "goes under the total number of documents");
            }
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
