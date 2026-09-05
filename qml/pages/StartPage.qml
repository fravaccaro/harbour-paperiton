import QtQuick 2.0
import Sailfish.Silica 1.0

// Shown while there is nothing to do but wait to find out whether the app is
// signed in: at the start, while the API token is read back from Sailfish
// Secrets, and after the sign-in form is accepted, while the server answers.
Page {
    allowedOrientations: Orientation.All

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: true
    }
}
