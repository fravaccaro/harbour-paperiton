import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import harbour.paperiton 1.0

Page {
    id: page

    // Files handed over by another app; the picker and the camera add more.
    property var filePaths: []

    property int correspondentId: -1
    property int documentTypeId: -1
    property var tagIds: []

    allowedOrientations: Orientation.All

    function addFile(path, temporary) {
        for (var i = 0; i < pending.count; ++i) {
            if (pending.get(i).filePath === path)
                return
        }
        pending.append({ "filePath": path, "temporary": temporary === true })
    }

    function baseName(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    function metadata() {
        var data = {}
        if (pending.count === 1 && titleField.text.trim() !== "")
            data.title = titleField.text.trim()
        if (page.correspondentId > 0)
            data.correspondent = page.correspondentId
        if (page.documentTypeId > 0)
            data.document_type = page.documentTypeId
        if (page.tagIds.length > 0)
            data.tags = page.tagIds
        return data
    }

    function startUpload() {
        var data = page.metadata()
        while (pending.count > 0) {
            var entry = pending.get(0)
            Uploads.enqueue(entry.filePath, data, entry.temporary)
            pending.remove(0)
        }
        titleField.text = ""
    }

    function statusText(status, message, documentId) {
        switch (status) {
        case UploadQueue.Waiting:
            return qsTr("Waiting")
        case UploadQueue.Uploading:
            return qsTr("Sending")
        case UploadQueue.Processing:
            return qsTr("The server is processing the file")
        case UploadQueue.Completed:
            return documentId > 0 ? qsTr("Added as document %1").arg(documentId) : qsTr("Added")
        default:
            return message !== "" ? message : qsTr("Failed")
        }
    }

    Component.onCompleted: {
        for (var i = 0; i < filePaths.length; ++i)
            addFile(filePaths[i], false)
    }

    ListModel {
        id: pending
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: Uploads

        PullDownMenu {
            MenuItem {
                text: qsTr("Clear finished")
                visible: Uploads.count > Uploads.activeCount
                onClicked: Uploads.clearFinished()
            }

            MenuItem {
                text: qsTr("Scan with the camera")
                onClicked: {
                    var camera = pageStack.push(Qt.resolvedUrl("CameraPage.qml"))
                    camera.captured.connect(function(filePath) {
                        page.addFile(filePath, true)
                    })
                }
            }

            MenuItem {
                text: qsTr("Add files")
                onClicked: {
                    var picker = pageStack.push(pickerDialog)
                    picker.accepted.connect(function() {
                        for (var i = 0; i < picker.selectedContent.count; ++i)
                            page.addFile(picker.selectedContent.get(i).filePath, false)
                    })
                }
            }
        }

        header: Column {
            width: listView.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Upload")
                description: {
                    if (Uploads.activeCount === 0)
                        return ""
                    if (Uploads.activeCount === 1)
                        return qsTr("One file in progress")
                    return qsTr("%1 files in progress").arg(Uploads.activeCount)
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: pending.count === 0 && Uploads.count === 0
                wrapMode: Text.WordWrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Pull down to pick files from the device or to scan a document with the camera. "
                           + "Other apps can also share files with Paperiton.")
            }

            Column {
                width: parent.width
                visible: pending.count > 0

                SectionHeader { text: qsTr("Ready to upload") }

                Repeater {
                    model: pending

                    ListItem {
                        width: parent.width
                        contentHeight: Theme.itemSizeSmall

                        menu: ContextMenu {
                            MenuItem {
                                text: qsTr("Remove")
                                onClicked: pending.remove(index)
                            }
                        }

                        Label {
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            truncationMode: TruncationMode.Fade
                            text: page.baseName(model.filePath)
                        }
                    }
                }

                TextField {
                    id: titleField
                    width: parent.width
                    visible: pending.count === 1
                    label: qsTr("Title")
                    placeholderText: qsTr("Title on the server")
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    EnterKey.onClicked: focus = false
                }

                ValueButton {
                    label: qsTr("Correspondent")
                    value: page.correspondentId > 0 && Correspondents.ready
                           ? Correspondents.nameFor(page.correspondentId) : qsTr("None")
                    onClicked: {
                        var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                        lookup: Correspondents,
                                                        heading: qsTr("Correspondent"),
                                                        selectedId: page.correspondentId
                                                    })
                        picker.accepted.connect(function() {
                            page.correspondentId = picker.selectedId
                        })
                    }
                }

                ValueButton {
                    label: qsTr("Type")
                    value: page.documentTypeId > 0 && DocumentTypes.ready
                           ? DocumentTypes.nameFor(page.documentTypeId) : qsTr("None")
                    onClicked: {
                        var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                        lookup: DocumentTypes,
                                                        heading: qsTr("Type"),
                                                        selectedId: page.documentTypeId
                                                    })
                        picker.accepted.connect(function() {
                            page.documentTypeId = picker.selectedId
                        })
                    }
                }

                ValueButton {
                    label: qsTr("Tags")
                    value: page.tagIds.length > 0 && Tags.ready ? Tags.namesFor(page.tagIds).join(", ")
                                                                : qsTr("None")
                    onClicked: {
                        var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                        lookup: Tags,
                                                        heading: qsTr("Tags"),
                                                        multiple: true,
                                                        selectedIds: page.tagIds
                                                    })
                        picker.accepted.connect(function() {
                            page.tagIds = picker.selectedIds
                        })
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pending.count > 1 ? qsTr("Upload %1 files").arg(pending.count) : qsTr("Upload")
                    onClicked: page.startUpload()
                }

                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                }
            }

            SectionHeader {
                text: qsTr("Queue")
                visible: Uploads.count > 0
            }
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
                                                  documentTitle: model.title !== "" ? model.title
                                                                                    : model.fileName
                                              })
                }

                MenuItem {
                    text: qsTr("Try again")
                    visible: model.status === UploadQueue.Failed
                    onClicked: Uploads.retry(index)
                }

                MenuItem {
                    text: qsTr("Remove")
                    visible: model.status !== UploadQueue.Uploading
                    onClicked: Uploads.remove(index)
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
                    text: model.fileName
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: model.status === UploadQueue.Failed ? Theme.errorColor : Theme.secondaryColor
                    text: page.statusText(model.status, model.message, model.documentId)
                }

                ProgressBar {
                    width: parent.width
                    visible: model.status === UploadQueue.Uploading
                    minimumValue: 0
                    maximumValue: 1
                    value: model.progress
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Component {
        id: pickerDialog

        MultiContentPickerDialog {
            title: qsTr("Select files")
        }
    }
}
