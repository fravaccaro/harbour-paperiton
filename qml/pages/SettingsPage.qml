import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Settings") }

            SectionHeader { text: qsTr("Server") }

            DetailItem {
                label: qsTr("Address")
                value: Settings.serverUrl
            }

            DetailItem {
                label: qsTr("User")
                value: Settings.username
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("Documents")
                value: Paperless.totalDocuments > 0 ? String(Paperless.totalDocuments) : ""
                visible: value !== ""
            }

            TextSwitch {
                text: qsTr("Ignore certificate errors")
                description: qsTr("Only for a server with a self-signed certificate on your own network.")
                checked: Settings.ignoreSslErrors
                onClicked: Settings.ignoreSslErrors = checked
            }

            SectionHeader { text: qsTr("Storage") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Opened documents are saved to the Downloads folder so that other apps can read them.")
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear thumbnail cache")
                onClicked: cacheRemorse.execute(qsTr("Clearing thumbnail cache"),
                                                function() { Paperless.clearCache() })
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Sign out")
                onClicked: signOutRemorse.execute(qsTr("Signing out"), function() { Paperless.logout() })
            }
        }

        RemorsePopup { id: signOutRemorse }
        RemorsePopup { id: cacheRemorse }

        VerticalScrollDecorator {}
    }
}
