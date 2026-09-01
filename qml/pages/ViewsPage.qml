import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property QtObject documents

    allowedOrientations: Orientation.All

    function apply(filters, ordering, tagId) {
        documents.searchQuery = ""
        documents.correspondentId = -1
        documents.tagId = tagId
        documents.ordering = ordering
        documents.filters = filters
        pageStack.pop()
    }

    onStatusChanged: {
        if (status === PageStatus.Active && SavedViews.count === 0 && !SavedViews.loading)
            SavedViews.reload()
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: SavedViews

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: SavedViews.reload()
            }
        }

        header: Column {
            width: listView.width

            PageHeader { title: qsTr("Views") }

            BackgroundItem {
                width: parent.width
                onClicked: page.apply({}, "", -1)

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("All documents")
                }
            }

            BackgroundItem {
                width: parent.width
                visible: Tags.inboxTagId > 0
                onClicked: page.apply({}, "", Tags.inboxTagId)

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Inbox")
                }
            }

            SectionHeader {
                text: qsTr("Saved views")
                visible: SavedViews.count > 0
            }
        }

        delegate: BackgroundItem {
            id: item

            width: listView.width
            enabled: model.supported

            onClicked: page.apply(SavedViews.filtersFor(index), SavedViews.orderingFor(index), -1)

            Column {
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: model.name
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    opacity: model.supported ? 1.0 : Theme.opacityLow
                }

                Label {
                    width: parent.width
                    visible: !model.supported
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: qsTr("Uses filters this app does not support")
                }
            }
        }

        ViewPlaceholder {
            enabled: SavedViews.count === 0 && !SavedViews.loading
            text: qsTr("No saved views")
            hintText: qsTr("Views that you save in the web interface show up here.")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: SavedViews.loading && SavedViews.count === 0
    }
}
