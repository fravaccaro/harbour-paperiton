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

    property var selectedIds: []

    property var bulkOperations: []
    property int bulkIndex: -1
    property string bulkError

    allowedOrientations: Orientation.All

    function runBulk(operations) {
        bulkError = ""
        bulkOperations = operations
        bulkIndex = -1
        nextBulkOperation()
    }

    function nextBulkOperation() {
        bulkIndex++
        if (bulkIndex >= bulkOperations.length) {
            bulkIndex = -1
            selectedIds = []
            documents.reload()
            return
        }

        var operation = bulkOperations[bulkIndex]
        Paperless.bulkEdit(selectedIds, operation.method, operation.parameters)
    }

    function startSelection(documentId) {
        selectedIds = [documentId]
    }

    function toggleSelection(documentId) {
        var ids = selectedIds.slice()
        var at = ids.indexOf(documentId)
        if (at >= 0)
            ids.splice(at, 1)
        else
            ids.push(documentId)
        selectedIds = ids
    }

    function isSelected(documentId) {
        return selectedIds.indexOf(documentId) >= 0
    }

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
        if (status !== PageStatus.Active)
            return

        // Opening a document drops the attachment, so it is put back every time
        // this page becomes current again.
        if (!pageStack.nextPage(page))
            pageStack.pushAttached(Qt.resolvedUrl("FilterPage.qml"), { documents: documents })

        if (documents.count === 0 && !documents.loading)
            documents.reload()
    }

    DocumentListModel {
        id: documents
    }

    Connections {
        target: Uploads
        onUploadCompleted: documents.reload()
    }

    Connections {
        target: Paperless

        onBulkEditFinished: {
            if (page.bulkIndex < 0)
                return

            if (error !== "") {
                page.bulkIndex = -1
                page.bulkError = error
                return
            }

            page.nextBulkOperation()
        }
    }

    // Coming back after a while should not show yesterday's list, but a reload
    // empties the model and sends the view back to the top, so a short glance at
    // the cover leaves the list as it was.
    Connections {
        target: app
        onApplicationActiveChanged: {
            if (app.applicationActive && Paperless.authenticated)
                documents.reloadIfStale(300)
        }
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: documents

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Documents")
                description: page.selectedIds.length > 0
                             ? qsTr("%1 selected").arg(page.selectedIds.length) : page.filterSummary
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.bulkError !== ""
                wrapMode: Text.WordWrap
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.bulkError
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

            // The header is a component of its own, so everything that reaches
            // for the field has to live in here with it.
            Timer {
                id: searchDelay
                interval: 600
                onTriggered: documents.searchQuery = searchField.text.trim()
            }

            Connections {
                target: documents
                onSearchQueryChanged: {
                    if (searchField.text === documents.searchQuery)
                        return

                    searchField.text = documents.searchQuery
                    searchDelay.stop()
                }
            }
        }

        PullDownMenu {
            MenuItem {
                text: page.selectedIds.length === 1
                      ? qsTr("Edit one document")
                      : qsTr("Edit %1 documents").arg(page.selectedIds.length)
                visible: page.selectedIds.length > 0
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("BulkEditPage.qml"), {
                                                    documentCount: page.selectedIds.length
                                                })
                    dialog.accepted.connect(function() {
                        page.runBulk(dialog.operations())
                    })
                }
            }

            MenuItem {
                text: qsTr("Cancel selection")
                visible: page.selectedIds.length > 0
                onClicked: page.selectedIds = []
            }

            MenuItem {
                text: Uploads.activeCount > 0 ? qsTr("Uploads (%1)").arg(Uploads.activeCount)
                                              : qsTr("Upload")
                visible: page.selectedIds.length === 0 && app.allowed("add_document")
                onClicked: pageStack.push(Qt.resolvedUrl("UploadPage.qml"))
            }

            MenuItem {
                text: qsTr("Refresh")
                visible: page.selectedIds.length === 0
                onClicked: documents.reload()
            }
        }

        delegate: ListItem {
            id: item

            property var documentTags: model.tagIds
            property bool selected: page.isSelected(model.documentId)

            contentHeight: Theme.itemSizeLarge
            highlighted: down || selected

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Select")
                    visible: page.selectedIds.length === 0 && app.allowed("change_document")
                    onClicked: page.startSelection(model.documentId)
                }
            }

            onClicked: {
                if (page.selectedIds.length > 0) {
                    page.toggleSelection(model.documentId)
                    return
                }

                pageStack.push(Qt.resolvedUrl("DocumentPage.qml"), {
                                   documentId: model.documentId,
                                   documentTitle: model.title,
                                   created: model.created,
                                   correspondentId: model.correspondentId,
                                   tagIds: model.tagIds
                               })
            }

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
                        opacity: item.selected ? Theme.opacityLow : 1.0
                    }

                    Image {
                        anchors.centerIn: parent
                        visible: item.selected
                        source: "image://theme/icon-s-installed?" + Theme.highlightColor
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
