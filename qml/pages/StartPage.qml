import QtQuick 2.0
import Sailfish.Silica 1.0

// Shown while the API token is read back from Sailfish Secrets, which happens
// after the window is already up.
Page {
    allowedOrientations: Orientation.All

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: true
    }
}
