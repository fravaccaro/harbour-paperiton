import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.paperiton 1.0

CoverBackground {
    id: cover

    // Held apart from the model: reloading blanks totalCount while the request
    // is in flight, and the cover is on screen the whole time.
    property int inboxCount: 0

    readonly property bool uploading: Uploads.activeCount > 0
    readonly property bool showInbox: !uploading && inboxCount > 0
    readonly property int headline: uploading ? Uploads.activeCount
                                              : showInbox ? inboxCount
                                                          : Paperless.totalDocuments

    clip: true

    HighlightImage {
        source: Qt.resolvedUrl("cover-tag.png")
        color: Theme.primaryColor
        sourceSize.width: cover.width * 0.8
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
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.paddingMedium
        }
        spacing: Theme.paddingSmall

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
                    return qsTr("Not signed in")
                if (cover.uploading)
                    return qsTr("uploading", "goes under the number of files being uploaded")
                if (cover.showInbox)
                    return qsTr("in inbox", "goes under the number of documents in the inbox")
                if (Paperless.totalDocuments === 0)
                    return qsTr("No documents yet")
                return qsTr("documents", "goes under the total number of documents")
            }
        }
    }

    BusyIndicator {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge
        }
        size: BusyIndicatorSize.Small
        running: cover.uploading
    }

    DocumentListModel {
        id: inboxModel

        // Only totalCount is read, so there is no point in carrying a whole
        // page of documents back from the server.
        pageSize: 1
        onLoadingChanged: {
            if (!loading && tagId > 0)
                cover.inboxCount = totalCount
        }
    }

    // The tag id is only known once the server has answered, and asking with
    // no tag at all would count every document instead.
    Binding {
        target: inboxModel
        property: "tagId"
        value: Tags.inboxTagId
        when: Paperless.authenticated && Tags.inboxTagId > 0
    }

    Connections {
        target: Paperless
        onAuthenticatedChanged: {
            if (!Paperless.authenticated)
                cover.inboxCount = 0
        }
    }

    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active && inboxModel.tagId > 0)
                inboxModel.reloadIfStale(120)
        }
    }
}
