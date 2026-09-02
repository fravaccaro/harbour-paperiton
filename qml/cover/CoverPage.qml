import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Paperiton")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeLarge
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            text: {
                if (!Paperless.authenticated)
                    return qsTr("Not signed in")
                if (Uploads.activeCount === 1)
                    return qsTr("Uploading one file")
                if (Uploads.activeCount > 1)
                    return qsTr("Uploading %1 files").arg(Uploads.activeCount)
                if (Paperless.totalDocuments === 0)
                    return qsTr("No documents yet")
                if (Paperless.totalDocuments === 1)
                    return qsTr("One document")
                return qsTr("%1 documents").arg(Paperless.totalDocuments)
            }
        }
    }
}
