import QtQuick 2.0
import Sailfish.Silica 1.0

// Shown while there is nothing to do but wait to find out whether the app is
// signed in: at the start, while the API token is read back from Sailfish
// Secrets, and after the sign-in form is accepted, while the server answers.
// A read that did not get through waits here as well, since a secure storage
// that could not be asked is not the same as not being signed in.
Page {
    readonly property bool stalled: !Settings.ready && Settings.secretsError !== ""

    allowedOrientations: Orientation.All

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: !stalled
        visible: running
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Theme.paddingLarge
        visible: stalled

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Theme.highlightColor
            text: qsTr("The API token could not be read from the secure storage of Sailfish OS.")
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: Settings.secretsError
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Try again")
            onClicked: Settings.reloadSecrets()
        }

    }

}
