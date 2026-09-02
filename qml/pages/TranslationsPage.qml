import QtQuick 2.0
import Sailfish.Silica 1.0
import Opal.LinkHandler 1.0 as L

Page {
    id: page

    readonly property string transifex: "https://explore.transifex.com/fravaccaro/paperiton"

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Translations") }

            DetailItem {
                label: "Italiano"
                value: "Francesco Vaccaro"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("The app is written in English. To add a language, or to improve "
                           + "one that is already there, join the project on Transifex.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Transifex"
                onClicked: L.LinkHandler.openOrCopyUrl(page.transifex, text)
            }
        }

        VerticalScrollDecorator {}
    }
}
