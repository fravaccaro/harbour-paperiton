import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property int documentCount

    property var addTagIds: []
    property var removeTagIds: []
    property int correspondentId: -1
    property int documentTypeId: -1

    allowedOrientations: Orientation.All
    canAccept: addTagIds.length > 0 || removeTagIds.length > 0 || correspondentId > 0
               || documentTypeId > 0

    // The server applies one change per call, so the caller runs them in turn.
    function operations() {
        var planned = []
        if (addTagIds.length > 0 || removeTagIds.length > 0) {
            planned.push({ "method": "modify_tags",
                           "parameters": { "add_tags": addTagIds, "remove_tags": removeTagIds } })
        }
        if (correspondentId > 0)
            planned.push({ "method": "set_correspondent", "parameters": { "correspondent": correspondentId } })
        if (documentTypeId > 0)
            planned.push({ "method": "set_document_type", "parameters": { "document_type": documentTypeId } })
        return planned
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column

            width: dialog.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Edit %n document(s)", "", dialog.documentCount)
                acceptText: qsTr("Apply")
            }

            ValueButton {
                label: qsTr("Add tags")
                value: dialog.addTagIds.length > 0 && Tags.ready ? Tags.namesFor(dialog.addTagIds).join(", ")
                                                                 : qsTr("None")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                    lookup: Tags,
                                                    heading: qsTr("Add tags"),
                                                    multiple: true,
                                                    selectedIds: dialog.addTagIds
                                                })
                    picker.accepted.connect(function() {
                        dialog.addTagIds = picker.selectedIds
                    })
                }
            }

            ValueButton {
                label: qsTr("Remove tags")
                value: dialog.removeTagIds.length > 0 && Tags.ready
                       ? Tags.namesFor(dialog.removeTagIds).join(", ") : qsTr("None")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                    lookup: Tags,
                                                    heading: qsTr("Remove tags"),
                                                    multiple: true,
                                                    selectedIds: dialog.removeTagIds
                                                })
                    picker.accepted.connect(function() {
                        dialog.removeTagIds = picker.selectedIds
                    })
                }
            }

            ValueButton {
                label: qsTr("Correspondent")
                value: dialog.correspondentId > 0 && Correspondents.ready
                       ? Correspondents.nameFor(dialog.correspondentId) : qsTr("Unchanged")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                    lookup: Correspondents,
                                                    heading: qsTr("Correspondent"),
                                                    selectedId: dialog.correspondentId
                                                })
                    picker.accepted.connect(function() {
                        dialog.correspondentId = picker.selectedId
                    })
                }
            }

            ValueButton {
                label: qsTr("Type")
                value: dialog.documentTypeId > 0 && DocumentTypes.ready
                       ? DocumentTypes.nameFor(dialog.documentTypeId) : qsTr("Unchanged")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                                                    lookup: DocumentTypes,
                                                    heading: qsTr("Type"),
                                                    selectedId: dialog.documentTypeId
                                                })
                    picker.accepted.connect(function() {
                        dialog.documentTypeId = picker.selectedId
                    })
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
