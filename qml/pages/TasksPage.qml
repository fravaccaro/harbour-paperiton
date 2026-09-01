import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    function statusText(status) {
        switch (status.toUpperCase()) {
        case "SUCCESS":
            return qsTr("Done")
        case "FAILURE":
            return qsTr("Failed")
        case "STARTED":
            return qsTr("Running")
        case "PENDING":
            return qsTr("Waiting")
        default:
            return status
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active)
            Tasks.reload()
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: Tasks

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: Tasks.reload()
            }

            MenuItem {
                text: Tasks.failedOnly ? qsTr("Show all tasks") : qsTr("Show only failures")
                onClicked: Tasks.failedOnly = !Tasks.failedOnly
            }
        }

        header: PageHeader {
            title: qsTr("Tasks")
            description: Tasks.failedOnly ? qsTr("Failures only") : ""
        }

        delegate: ListItem {
            id: item

            width: listView.width
            contentHeight: Theme.itemSizeLarge

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Open document")
                    visible: model.documentId > 0
                    onClicked: pageStack.push(Qt.resolvedUrl("DocumentPage.qml"), {
                                                  documentId: model.documentId,
                                                  documentTitle: model.fileName
                                              })
                }

                MenuItem {
                    text: qsTr("Acknowledge")
                    visible: !model.acknowledged
                    onClicked: Tasks.acknowledge(index)
                }
            }

            Column {
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: model.fileName !== "" ? model.fileName : model.name
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: model.status.toUpperCase() === "FAILURE" ? Theme.errorColor
                                                                    : Theme.secondaryColor
                    text: {
                        var parts = [page.statusText(model.status)]
                        if (model.created && !isNaN(model.created.getTime()))
                            parts.push(Qt.formatDateTime(model.created, Qt.DefaultLocaleShortDate))
                        if (model.result !== "")
                            parts.push(model.result)
                        return parts.join("  \u00b7  ")
                    }
                }
            }
        }

        ViewPlaceholder {
            enabled: Tasks.count === 0 && !Tasks.loading
            text: Tasks.errorString !== "" ? qsTr("Could not load tasks") : qsTr("Nothing in the queue")
            hintText: Tasks.errorString
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: Tasks.loading && Tasks.count === 0
    }
}
