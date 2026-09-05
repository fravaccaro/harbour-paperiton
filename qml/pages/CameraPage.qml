import QtMultimedia 5.4
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property int captureCount: 0
    property string errorMessage
    readonly property bool viewfinderReady: viewfinderLoader.item !== null

    signal captured(string filePath)

    function capture() {
        if (!page.viewfinderReady)
            return ;

        var path = Uploads.captureFilePath("jpg");
        if (path === "") {
            page.errorMessage = qsTr("The picture could not be saved.");
            return ;
        }
        page.errorMessage = "";
        viewfinderLoader.item.capture(path);
    }

    // The viewfinder is only sensibly usable upright.
    allowedOrientations: Orientation.Portrait
    // Building the camera pipeline takes seconds and holds the thread that asks
    // for it, which froze the page transition when the camera was part of the
    // page. It is now built after the transition, with the delay giving the busy
    // indicator a frame of its own first.
    onStatusChanged: {
        if (status === PageStatus.Active) {
            startDelay.start();
        } else if (status === PageStatus.Deactivating) {
            startDelay.stop();
            viewfinderLoader.active = false;
        }
    }

    Timer {
        id: startDelay

        interval: 300
        onTriggered: viewfinderLoader.active = true
    }

    Loader {
        id: viewfinderLoader

        active: false
        asynchronous: true
        sourceComponent: viewfinderComponent

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: controls.top
        }

    }

    Component {
        id: viewfinderComponent

        VideoOutput {
            readonly property bool captureReady: camera.imageCapture.ready
            readonly property bool flashOn: camera.flash.mode !== Camera.FlashOff

            function capture(path) {
                camera.imageCapture.captureToLocation(path);
            }

            function toggleFlash() {
                camera.flash.mode = flashOn ? Camera.FlashOff : Camera.FlashOn;
            }

            source: camera
            fillMode: VideoOutput.PreserveAspectFit
            orientation: 0

            Camera {
                id: camera

                captureMode: Camera.CaptureStillImage

                focus {
                    focusMode: Camera.FocusContinuous
                    focusPointMode: Camera.FocusPointAuto
                }

                imageCapture {
                    onImageSaved: {
                        page.captureCount++;
                        page.captured(path);
                    }
                    onCaptureFailed: page.errorMessage = message
                }

            }

        }

    }

    BusyIndicator {
        anchors.centerIn: viewfinderLoader
        size: BusyIndicatorSize.Large
        running: !page.viewfinderReady
    }

    Label {
        width: page.width - 2 * Theme.horizontalPageMargin
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: page.errorMessage !== "" ? Theme.errorColor : Theme.highlightColor
        font.pixelSize: Theme.fontSizeSmall
        text: {
            if (page.errorMessage !== "")
                return page.errorMessage;

            if (page.captureCount === 1)
                return qsTr("One page captured");

            if (page.captureCount > 1)
                return qsTr("%1 pages captured").arg(page.captureCount);

            return qsTr("Place the document in the frame");
        }

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: viewfinderLoader.top
            topMargin: Theme.paddingLarge
        }

    }

    Row {
        id: controls

        spacing: Theme.paddingLarge * 2

        anchors {
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge
            horizontalCenter: parent.horizontalCenter
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            enabled: page.viewfinderReady
            icon.source: "image://theme/icon-camera-flash-" + (page.viewfinderReady && viewfinderLoader.item.flashOn ? "on" : "off")
            onClicked: viewfinderLoader.item.toggleFlash()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-camera-shutter"
            enabled: page.viewfinderReady && viewfinderLoader.item.captureReady
            onClicked: page.capture()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-acknowledge"
            onClicked: pageStack.pop()
        }

    }

}
