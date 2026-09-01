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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: Paperless.accessWarning !== ""
                wrapMode: Text.WordWrap
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("This account cannot read documents: %1").arg(Paperless.accessWarning)
            }

            SectionHeader { text: qsTr("Storage") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("The API token is kept in the encrypted storage of Sailfish OS. "
                           + "Documents you open are downloaded to the private cache of the app "
                           + "and deleted again when the app closes; \"Save to Downloads\" keeps a copy.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: Settings.secretsError !== ""
                wrapMode: Text.WordWrap
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Secure storage reported: %1").arg(Settings.secretsError)
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear cache")
                onClicked: cacheRemorse.execute(qsTr("Clearing cache"),
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
