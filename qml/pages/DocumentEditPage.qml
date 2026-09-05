import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property int documentId
    property var details: ({
    })
    property string documentTitle
    property int correspondentId: -1
    property int documentTypeId: -1
    property var tagIds: []
    property var created
    // Field id to the value shown in the form, for the server's custom fields.
    property var customValues: ({
    })

    function customValue(fieldId) {
        return customValues[fieldId] !== undefined ? customValues[fieldId] : "";
    }

    function setCustomValue(fieldId, value) {
        var values = {
        };
        for (var key in customValues) values[key] = customValues[key]
        values[fieldId] = value;
        customValues = values;
    }

    // Links to other documents and select fields need a picker this app does
    // not have, so their value is only shown.
    function isEditable(dataType) {
        return dataType !== "documentlink" && dataType !== "select";
    }

    function customFieldsPatch() {
        var entries = [];
        for (var key in customValues) {
            var fieldId = parseInt(key, 10);
            var dataType = CustomFields.dataTypeFor(fieldId);
            if (!isEditable(dataType))
                continue;

            var value = customValues[key];
            if (value === "" || value === undefined || value === null)
                entries.push({
                "field": fieldId,
                "value": null
            });
            else if (dataType === "integer")
                entries.push({
                "field": fieldId,
                "value": parseInt(value, 10)
            });
            else if (dataType === "float")
                entries.push({
                "field": fieldId,
                "value": parseFloat(value)
            });
            else if (dataType === "boolean")
                entries.push({
                "field": fieldId,
                "value": value === true || value === "true"
            });
            else
                entries.push({
                "field": fieldId,
                "value": String(value)
            });
        }
        return entries;
    }

    function apply() {
        var fields = {
        };
        fields.title = titleField.text.trim();
        fields.correspondent = correspondentId > 0 ? correspondentId : null;
        fields.document_type = documentTypeId > 0 ? documentTypeId : null;
        fields.tags = tagIds;
        if (created && !isNaN(created.getTime()))
            fields.created = Qt.formatDate(created, "yyyy-MM-dd");

        var serial = serialField.text.trim();
        fields.archive_serial_number = serial !== "" ? parseInt(serial, 10) : null;
        var custom = customFieldsPatch();
        if (custom.length > 0)
            fields.custom_fields = custom;

        Paperless.patchDocument(documentId, fields);
    }

    allowedOrientations: Orientation.All
    canAccept: titleField.text.trim() !== ""
    Component.onCompleted: {
        var values = {
        };
        var existing = details.custom_fields || [];
        for (var i = 0; i < existing.length; ++i) values[existing[i].field] = existing[i].value !== null ? existing[i].value : ""
        customValues = values;
        if (CustomFields.count === 0)
            CustomFields.reload();

    }
    onAccepted: apply()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column

            width: dialog.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Edit")
                acceptText: qsTr("Save")
            }

            TextField {
                id: titleField

                width: parent.width
                text: dialog.documentTitle
                label: qsTr("Title")
                placeholderText: qsTr("Title")
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            ValueButton {
                label: qsTr("Correspondent")
                value: dialog.correspondentId > 0 && Correspondents.ready ? Correspondents.nameFor(dialog.correspondentId) : qsTr("None")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                        "lookup": Correspondents,
                        "heading": qsTr("Correspondent"),
                        "selectedId": dialog.correspondentId
                    });
                    picker.accepted.connect(function() {
                        dialog.correspondentId = picker.selectedId;
                    });
                }
            }

            ValueButton {
                label: qsTr("Type")
                value: dialog.documentTypeId > 0 && DocumentTypes.ready ? DocumentTypes.nameFor(dialog.documentTypeId) : qsTr("None")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                        "lookup": DocumentTypes,
                        "heading": qsTr("Type"),
                        "selectedId": dialog.documentTypeId
                    });
                    picker.accepted.connect(function() {
                        dialog.documentTypeId = picker.selectedId;
                    });
                }
            }

            ValueButton {
                label: qsTr("Tags")
                value: dialog.tagIds.length > 0 && Tags.ready ? Tags.namesFor(dialog.tagIds).join(", ") : qsTr("None")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LookupPickerPage.qml"), {
                        "lookup": Tags,
                        "heading": qsTr("Tags"),
                        "multiple": true,
                        "selectedIds": dialog.tagIds
                    });
                    picker.accepted.connect(function() {
                        dialog.tagIds = picker.selectedIds;
                    });
                }
            }

            ValueButton {
                label: qsTr("Created")
                value: dialog.created && !isNaN(dialog.created.getTime()) ? Qt.formatDate(dialog.created, Qt.DefaultLocaleShortDate) : qsTr("Unknown")
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog", {
                        "date": dialog.created && !isNaN(dialog.created.getTime()) ? dialog.created : new Date()
                    });
                    picker.accepted.connect(function() {
                        dialog.created = picker.date;
                    });
                }
            }

            TextField {
                id: serialField

                width: parent.width
                text: dialog.details.archive_serial_number ? String(dialog.details.archive_serial_number) : ""
                label: qsTr("Archive serial number")
                placeholderText: qsTr("Archive serial number")
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            SectionHeader {
                text: qsTr("Custom fields")
                visible: CustomFields.count > 0
            }

            Repeater {
                model: CustomFields

                Column {
                    width: column.width

                    TextField {
                        width: parent.width
                        visible: model.dataType !== "boolean" && dialog.isEditable(model.dataType)
                        label: model.name
                        placeholderText: model.name
                        inputMethodHints: model.dataType === "integer" || model.dataType === "float" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
                        EnterKey.iconSource: "image://theme/icon-m-enter-close"
                        EnterKey.onClicked: focus = false
                        Component.onCompleted: text = String(dialog.customValue(model.fieldId))
                        onTextChanged: dialog.setCustomValue(model.fieldId, text)
                    }

                    TextSwitch {
                        width: parent.width
                        visible: model.dataType === "boolean"
                        text: model.name
                        Component.onCompleted: checked = dialog.customValue(model.fieldId) === true
                        onClicked: dialog.setCustomValue(model.fieldId, checked)
                    }

                    DetailItem {
                        visible: !dialog.isEditable(model.dataType)
                        label: model.name
                        value: String(dialog.customValue(model.fieldId))
                    }

                }

            }

        }

        VerticalScrollDecorator {
        }

    }

}
