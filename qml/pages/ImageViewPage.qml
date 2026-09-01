import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property url source
    property string title

    allowedOrientations: Orientation.All

    SilicaFlickable {
        id: flickable

        anchors.fill: parent
        contentWidth: content.width
        contentHeight: content.height
        clip: true

        PinchArea {
            id: content

            width: Math.max(flickable.width, image.width * image.scale)
            height: Math.max(flickable.height, image.height * image.scale)
            pinch.target: image
            pinch.minimumScale: 1.0
            pinch.maximumScale: 6.0
            pinch.dragAxis: Pinch.NoDrag

            Image {
                id: image

                anchors.centerIn: parent
                width: flickable.width
                height: flickable.height
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                transformOrigin: Item.Center
                source: page.source
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: image.status === Image.Loading
        }

        ViewPlaceholder {
            enabled: image.status === Image.Error
            text: qsTr("Could not show this file")
        }
    }

    PageHeader {
        title: page.title
        opacity: flickable.moving ? 0.0 : 1.0
        Behavior on opacity { FadeAnimation {} }
    }
}
