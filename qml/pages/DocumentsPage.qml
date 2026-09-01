import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.paperiton 1.0

Page {
    id: page

    property string filterSummary: {
        var parts = []
        if (documents.tagId > 0 && Tags.ready)
            parts.push(Tags.nameFor(documents.tagId))
        if (documents.correspondentId > 0 && Correspondents.ready)
            parts.push(Correspondents.nameFor(documents.correspondentId))
        return parts.join("  \u00b7  ")
    }

    allowedOrientations: Orientation.All

    function subtitle(created, correspondentId, lookupsReady) {
        var parts = []
        if (created && !isNaN(created.getTime()))
            parts.push(Qt.formatDate(created, Qt.DefaultLocaleShortDate))
        if (lookupsReady && correspondentId > 0) {
            var name = Correspondents.nameFor(correspondentId)
            if (name !== "")
                parts.push(name)
        }
        return parts.join("  \u00b7  ")
    }

    onStatusChanged: {
        if (status === PageStatus.Active && documents.count === 0 && !documents.loading)
            documents.reload()
    }

    DocumentListModel {
        id: documents
    }

    Timer {
        id: searchDelay
        interval: 600
        onTriggered: documents.searchQuery = searchField.text.trim()
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: documents

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Documents")
                description: page.filterSummary
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search documents")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: {
                    searchDelay.stop()
                    documents.searchQuery = text.trim()
                    focus = false
                }
                onTextChanged: searchDelay.restart()
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }

            MenuItem {
                text: qsTr("Clear filters")
                visible: documents.tagId > 0 || documents.correspondentId > 0
                onClicked: {
                    documents.tagId = -1
                    documents.correspondentId = -1
                }
            }

            MenuItem {
                text: qsTr("Filter")
                onClicked: pageStack.push(Qt.resolvedUrl("FilterPage.qml"), { documents: documents })
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: documents.reload()
            }
        }

        delegate: ListItem {
            id: item

            property var documentTags: model.tagIds

            contentHeight: Theme.itemSizeLarge

            onClicked: pageStack.push(Qt.resolvedUrl("DocumentPage.qml"), {
                                          documentId: model.documentId,
                                          documentTitle: model.title,
                                          created: model.created,
                                          correspondentId: model.correspondentId,
                                          tagIds: model.tagIds
                                      })

            Row {
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingMedium

                Rectangle {
                    id: thumbnailFrame

                    width: Theme.itemSizeSmall * 0.72
                    height: Theme.itemSizeLarge - 2 * Theme.paddingSmall
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                    radius: Theme.paddingSmall / 2
                    clip: true

                    Image {
                        anchors.fill: parent
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignTop
                        source: model.thumbnailSource
                    }
                }

                Column {
                    width: parent.width - thumbnailFrame.width - Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingSmall / 2

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        text: model.title
                        color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        text: page.subtitle(model.created, model.correspondentId, Correspondents.ready)
                    }

                    Row {
                        spacing: Theme.paddingSmall
                        visible: Tags.ready && item.documentTags.length > 0

                        Repeater {
                            model: item.documentTags

                            Rectangle {
                                width: Theme.paddingSmall
                                height: width
                                radius: width / 2
                                color: {
                                    var tagColor = Tags.colorFor(modelData)
                                    return tagColor !== "" ? tagColor : Theme.secondaryColor
                                }
                            }
                        }
                    }
                }
            }
        }

        footer: Item {
            width: listView.width
            height: documents.loading && documents.count > 0 ? Theme.itemSizeSmall : Theme.paddingLarge

            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Small
                running: documents.loading && documents.count > 0
            }
        }

        onAtYEndChanged: {
            if (atYEnd && documents.canLoadMore)
                documents.loadMore()
        }

        ViewPlaceholder {
            enabled: !documents.loading && documents.count === 0
            text: {
                if (documents.errorString !== "")
                    return qsTr("Could not load documents")
                if (documents.searchQuery !== "" || documents.tagId > 0 || documents.correspondentId > 0)
                    return qsTr("Nothing found")
                return qsTr("No documents")
            }
            hintText: documents.errorString !== "" ? documents.errorString
                                                   : qsTr("Pull down to refresh")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: documents.loading && documents.count === 0
    }
}
