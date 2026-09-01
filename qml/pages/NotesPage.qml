import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property int documentId
    property string documentTitle

    property var notes: []
    property bool loading: true
    property string errorMessage

    allowedOrientations: Orientation.All

    function authorOf(note) {
        if (!note.user)
            return ""
        if (typeof note.user === "object")
            return note.user.username || ""
        return ""
    }

    function timeOf(note) {
        if (!note.created)
            return ""
        var created = new Date(note.created)
        return isNaN(created.getTime()) ? "" : Qt.formatDateTime(created, Qt.DefaultLocaleShortDate)
    }

    function subtitleOf(note) {
        var parts = []
        var author = authorOf(note)
        if (author !== "")
            parts.push(author)
        var time = timeOf(note)
        if (time !== "")
            parts.push(time)
        return parts.join("  \u00b7  ")
    }

    Component.onCompleted: Paperless.fetchNotes(documentId)

    Connections {
        target: Paperless

        onNotesFetched: {
            if (documentId !== page.documentId)
                return
            page.notes = notes
            page.loading = false
            page.errorMessage = ""
        }

        onNotesFailed: {
            if (documentId !== page.documentId)
                return
            page.loading = false
            page.errorMessage = error
        }
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: page.notes

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    page.loading = true
                    Paperless.fetchNotes(page.documentId)
                }
            }
        }

        header: Column {
            width: listView.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Notes")
                description: page.documentTitle
            }

            TextArea {
                id: noteField
                width: parent.width
                label: qsTr("New note")
                placeholderText: qsTr("Write a note")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Add note")
                enabled: noteField.text.trim() !== "" && app.allowed("add_note")
                onClicked: {
                    page.loading = true
                    Paperless.addNote(page.documentId, noteField.text.trim())
                    noteField.text = ""
                    noteField.focus = false
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.errorMessage !== ""
                wrapMode: Text.WordWrap
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.errorMessage
            }

            SectionHeader {
                text: qsTr("On this document")
                visible: page.notes.length > 0
            }
        }

        delegate: ListItem {
            id: item

            width: listView.width
            contentHeight: noteColumn.height + Theme.paddingLarge

            function remove() {
                remorseAction(qsTr("Deleting"), function() {
                    page.loading = true
                    Paperless.deleteNote(page.documentId, modelData.id)
                })
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Delete")
                    visible: app.allowed("delete_note")
                    onClicked: item.remove()
                }
            }

            Column {
                id: noteColumn

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
                    wrapMode: Text.WordWrap
                    text: modelData.note || ""
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: page.subtitleOf(modelData)
                }
            }
        }

        ViewPlaceholder {
            enabled: !page.loading && page.notes.length === 0 && page.errorMessage === ""
            text: qsTr("No notes")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: page.loading && page.notes.length === 0
    }
}
