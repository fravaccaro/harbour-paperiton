import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    readonly property string repository: "https://github.com/fravaccaro/harbour-paperiton"

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("About") }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "/usr/share/icons/hicolor/172x172/apps/harbour-paperiton.png"
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeLarge
                text: "Paperiton"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAnywhere
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("Version %1").arg(Qt.application.version)
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("A client for the documents of a Paperless-ngx server: search, "
                           + "filters, previews, uploads from the device or the camera, "
                           + "metadata, notes and the task queue.")
            }

            SectionHeader { text: qsTr("Details") }

            DetailItem {
                label: qsTr("Author")
                value: "fravaccaro"
            }

            DetailItem {
                label: qsTr("Licence")
                value: "GPLv3"
            }

            SectionHeader { text: qsTr("Links") }

            BackgroundItem {
                width: column.width
                onClicked: Qt.openUrlExternally(page.repository)

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    truncationMode: TruncationMode.Fade
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: qsTr("Source code")
                }
            }

            BackgroundItem {
                width: column.width
                onClicked: Qt.openUrlExternally(page.repository + "/issues")

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    truncationMode: TruncationMode.Fade
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: qsTr("Report an issue")
                }
            }

            BackgroundItem {
                width: column.width
                onClicked: Qt.openUrlExternally("https://docs.paperless-ngx.com")

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    truncationMode: TruncationMode.Fade
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: qsTr("About Paperless-ngx")
                }
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Paperless-ngx is a separate project and is not affiliated with "
                           + "this app.")
            }
        }

        VerticalScrollDecorator {}
    }
}
