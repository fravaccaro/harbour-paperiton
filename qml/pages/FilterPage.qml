import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    // Every choice on this page narrows the list and then shows it: this page is
    // attached to the list and is navigated away from, never popped.
    function apply(changes) {
        Documents.applyFilters(changes)
        pageStack.navigateBack()
    }

    // A view replaces the whole selection, tag and correspondent included. The
    // search stays: a view is where to search, not what to search for.
    function applyView(filters, ordering, tagId) {
        apply({
                  correspondentId: -1,
                  tagId: tagId,
                  // A view that names no order gets the order the list opens
                  // with, rather than whichever order the previous view asked for.
                  ordering: ordering === "" ? Documents.defaultOrdering : ordering,
                  filters: filters
              })
    }

    // Which entry of the Views section the document list is currently showing.
    // A search runs inside a view, so it does not change which one that is.
    readonly property bool showingAll: Documents.tagId <= 0 && Documents.correspondentId <= 0
                                       && Documents.ordering === Documents.defaultOrdering
                                       && Object.keys(Documents.filters).length === 0

    readonly property bool showingInbox: Tags.inboxTagId > 0
                                         && Documents.tagId === Tags.inboxTagId
                                         && Documents.correspondentId <= 0
                                         && Documents.ordering === Documents.defaultOrdering
                                         && Object.keys(Documents.filters).length === 0

    function showingView(index) {
        return Documents.tagId <= 0 && Documents.correspondentId <= 0
                && SavedViews.matches(index, Documents.filters, Documents.ordering)
    }

    // The names and the views are held for the whole run of the app, so opening
    // this page is the moment to catch up with what the server has meanwhile.
    onStatusChanged: {
        if (status !== PageStatus.Active)
            return

        SavedViews.reloadIfStale(300)
        Tags.reloadIfStale(300)
        Correspondents.reloadIfStale(300)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }

            MenuItem {
                text: qsTr("Tasks")
                onClicked: pageStack.push(Qt.resolvedUrl("TasksPage.qml"))
            }

            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }

            MenuItem {
                text: qsTr("Clear all filters")
                onClicked: {
                    Documents.clearFilters()
                    pageStack.navigateBack()
                }
            }
        }

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Filters") }

            SectionHeader { text: qsTr("Views") }

            BackgroundItem {
                width: parent.width
                onClicked: page.applyView({}, "", -1)

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("All documents")
                    color: page.showingAll ? Theme.highlightColor : Theme.primaryColor
                }
            }

            BackgroundItem {
                width: parent.width
                visible: Tags.inboxTagId > 0
                onClicked: page.applyView({}, "", Tags.inboxTagId)

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Inbox")
                    color: page.showingInbox ? Theme.highlightColor : Theme.primaryColor
                }
            }

            Repeater {
                model: SavedViews

                BackgroundItem {
                    id: viewItem

                    width: column.width
                    enabled: model.supported

                    onClicked: page.applyView(SavedViews.filtersFor(index),
                                              SavedViews.orderingFor(index), -1)

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
                            color: viewItem.highlighted || page.showingView(index)
                                   ? Theme.highlightColor : Theme.primaryColor
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
            }

            SectionHeader { text: qsTr("Tags") }

            BackgroundItem {
                width: parent.width
                onClicked: page.apply({ tagId: -1 })

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("All tags")
                    color: Documents.tagId <= 0 ? Theme.highlightColor : Theme.primaryColor
                }
            }

            Repeater {
                model: Tags

                BackgroundItem {
                    width: column.width
                    onClicked: page.apply({ tagId: model.itemId })

                    // The count keeps to the page margin whatever its number of
                    // digits, and the name gives way to it.
                    Item {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        height: parent.height

                        Rectangle {
                            id: dot

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            width: Theme.paddingMedium
                            height: width
                            radius: width / 2
                            color: model.color !== "" ? model.color : Theme.secondaryColor
                        }

                        Label {
                            id: countLabel

                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            text: model.documentCount > 0 ? model.documentCount : ""
                        }

                        Label {
                            anchors {
                                left: dot.right
                                leftMargin: Theme.paddingMedium
                                right: countLabel.left
                                rightMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            truncationMode: TruncationMode.Fade
                            text: model.name
                            color: Documents.tagId === model.itemId ? Theme.highlightColor
                                                                    : Theme.primaryColor
                        }
                    }
                }
            }

            SectionHeader { text: qsTr("Correspondents") }

            BackgroundItem {
                width: parent.width
                onClicked: page.apply({ correspondentId: -1 })

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("All correspondents")
                    color: Documents.correspondentId <= 0 ? Theme.highlightColor
                                                          : Theme.primaryColor
                }
            }

            Repeater {
                model: Correspondents

                BackgroundItem {
                    width: column.width
                    onClicked: page.apply({ correspondentId: model.itemId })

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        truncationMode: TruncationMode.Fade
                        text: model.name
                        color: Documents.correspondentId === model.itemId ? Theme.highlightColor
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
