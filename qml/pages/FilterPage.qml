import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property QtObject documents

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Filter") }

            SectionHeader { text: qsTr("Tag") }

            BackgroundItem {
                width: parent.width
                onClicked: page.documents.tagId = -1

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("All tags")
                    color: page.documents.tagId <= 0 ? Theme.highlightColor : Theme.primaryColor
                }
            }

            Repeater {
                model: Tags

                BackgroundItem {
                    width: column.width
                    onClicked: page.documents.tagId = model.itemId

                    Row {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingMedium

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.paddingMedium
                            height: width
                            radius: width / 2
                            color: model.color !== "" ? model.color : Theme.secondaryColor
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 2 * (Theme.paddingMedium + countLabel.width)
                            truncationMode: TruncationMode.Fade
                            text: model.name
                            color: page.documents.tagId === model.itemId ? Theme.highlightColor
                                                                         : Theme.primaryColor
                        }

                        Label {
                            id: countLabel
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            text: model.documentCount > 0 ? model.documentCount : ""
                        }
                    }
                }
            }

            SectionHeader { text: qsTr("Correspondent") }

            BackgroundItem {
                width: parent.width
                onClicked: page.documents.correspondentId = -1

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("All correspondents")
                    color: page.documents.correspondentId <= 0 ? Theme.highlightColor
                                                               : Theme.primaryColor
                }
            }

            Repeater {
                model: Correspondents

                BackgroundItem {
                    width: column.width
                    onClicked: page.documents.correspondentId = model.itemId

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        truncationMode: TruncationMode.Fade
                        text: model.name
                        color: page.documents.correspondentId === model.itemId ? Theme.highlightColor
                                                                               : Theme.primaryColor
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: (Tags.loading && Tags.count === 0) || (Correspondents.loading && Correspondents.count === 0)
    }
}
