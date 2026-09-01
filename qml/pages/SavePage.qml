import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property string archivedName
    property string originalName
    property bool hasOriginal: originalName !== ""

    readonly property string fileName: nameField.text.trim()
    readonly property bool original: originalSwitch.checked
    readonly property string destination: folderCombo.currentIndex === 1 ? "documents" : "downloads"

    allowedOrientations: Orientation.All

    canAccept: fileName !== ""

    function suggestedName() {
        return original && hasOriginal ? originalName : archivedName
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column

            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                acceptText: qsTr("Save")
                title: qsTr("Save on device")
            }

            ComboBox {
                id: folderCombo

                label: qsTr("Folder")
                currentIndex: 0

                menu: ContextMenu {
                    MenuItem { text: qsTr("Downloads") }
                    MenuItem { text: qsTr("Documents") }
                }
            }

            TextSwitch {
                id: originalSwitch

                visible: dialog.hasOriginal
                checked: true
                text: qsTr("Original file")
                description: qsTr("The file as it was uploaded, instead of the archived PDF.")
                onCheckedChanged: {
                    // Keeps following the switch until the name is edited by hand.
                    var previous = checked ? dialog.archivedName : dialog.originalName
                    if (nameField.text === previous)
                        nameField.text = dialog.suggestedName()
                }
            }

            TextField {
                id: nameField

                width: parent.width
                label: qsTr("File name")
                placeholderText: qsTr("File name")
                text: dialog.suggestedName()
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        VerticalScrollDecorator {}
    }
}
