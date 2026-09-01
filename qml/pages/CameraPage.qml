import QtQuick 2.0
import QtMultimedia 5.4
import Sailfish.Silica 1.0

Page {
    id: page

    signal captured(string filePath)

    property int captureCount: 0
    property string errorMessage

    // The viewfinder is only sensibly usable upright.
    allowedOrientations: Orientation.Portrait

    function capture() {
        var path = Uploads.captureFilePath("jpg")
        if (path === "") {
            page.errorMessage = qsTr("The picture could not be saved.")
            return
        }

        page.errorMessage = ""
        camera.imageCapture.captureToLocation(path)
    }

    onStatusChanged: {
        if (status === PageStatus.Active)
            camera.start()
        else if (status === PageStatus.Deactivating)
            camera.stop()
    }

    Camera {
        id: camera

        captureMode: Camera.CaptureStillImage
        focus {
            focusMode: Camera.FocusContinuous
            focusPointMode: Camera.FocusPointAuto
        }

        imageCapture {
            onImageSaved: {
                page.captureCount++
                page.captured(path)
            }

            onCaptureFailed: page.errorMessage = message
        }
    }

    VideoOutput {
        id: viewfinder

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: controls.top
        }
        source: camera
        fillMode: VideoOutput.PreserveAspectFit
        orientation: 0
    }

    Label {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: viewfinder.top
            topMargin: Theme.paddingLarge
        }
        width: page.width - 2 * Theme.horizontalPageMargin
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: page.errorMessage !== "" ? Theme.errorColor : Theme.highlightColor
        font.pixelSize: Theme.fontSizeSmall
        text: {
            if (page.errorMessage !== "")
                return page.errorMessage
            if (page.captureCount > 0)
                return qsTr("%n page(s) captured", "", page.captureCount)
            return qsTr("Place the document in the frame")
        }
    }

    Row {
        id: controls

        anchors {
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Theme.paddingLarge * 2

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-camera-flash-" + (camera.flash.mode === Camera.FlashOff ? "off" : "on")
            onClicked: camera.flash.mode = camera.flash.mode === Camera.FlashOff ? Camera.FlashOn
                                                                                 : Camera.FlashOff
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-camera-shutter"
            enabled: camera.imageCapture.ready
            onClicked: page.capture()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-acknowledge"
            onClicked: pageStack.pop()
        }
    }
}
