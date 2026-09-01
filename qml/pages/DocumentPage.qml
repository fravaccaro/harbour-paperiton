import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property int documentId
    property string documentTitle
    property var created
    property int correspondentId: -1
    property var tagIds: []

    property var details: ({})
    property bool loadingDetails: true
    property bool saving: false
    property string statusMessage
    property string errorMessage

    allowedOrientations: Orientation.All

    // The preview endpoint serves the archived PDF, the download endpoint the
    // file as it was consumed.
    function fileName(original) {
        var name = original ? (details.original_file_name || details.archived_file_name)
                            : (details.archived_file_name || details.original_file_name)
        if (name)
            return name
        return (documentTitle !== "" ? documentTitle : "paperless-" + documentId) + ".pdf"
    }

    function isImage() {
        var name = (details.original_file_name || "").toLowerCase()
        return /\.(png|jpe?g|gif|webp|bmp|tiff?)$/.test(name)
    }

    function open(original) {
        page.errorMessage = ""
        page.statusMessage = ""
        Paperless.saveDocument(documentId, fileName(original), original)
    }

    function formatDate(value) {
        if (!value || isNaN(value.getTime()))
            return ""
        return Qt.formatDate(value, Qt.DefaultLocaleLongDate)
    }

    onStatusChanged: {
        if (status === PageStatus.Active && loadingDetails)
            Paperless.fetchDocument(documentId)
    }

    Connections {
        target: Paperless

        onDocumentFetched: {
            if (documentId !== page.documentId)
                return
            page.details = document
            page.loadingDetails = false
            if (document.title)
                page.documentTitle = document.title
            if (document.tags)
                page.tagIds = document.tags
            if (document.correspondent !== undefined && document.correspondent !== null)
                page.correspondentId = document.correspondent
        }

        onDocumentFetchFailed: {
            if (documentId !== page.documentId)
                return
            page.loadingDetails = false
            page.errorMessage = error
        }

        onDocumentSaveStarted: {
            if (documentId === page.documentId)
                page.saving = true
        }

        onDocumentSaved: {
            if (documentId !== page.documentId)
                return
            page.saving = false
            page.statusMessage = qsTr("Saved to %1").arg(filePath)
            Qt.openUrlExternally(Paperless.fileUrl(filePath))
        }

        onDocumentSaveFailed: {
            if (documentId !== page.documentId)
                return
            page.saving = false
            page.errorMessage = error
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Open")
                enabled: !page.saving
                onClicked: page.open(false)
            }

            MenuItem {
                text: qsTr("Open original file")
                enabled: !page.saving
                onClicked: page.open(true)
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    page.loadingDetails = true
                    page.errorMessage = ""
                    Paperless.fetchDocument(page.documentId)
                }
            }
        }

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.documentTitle
                description: page.formatDate(page.created)
            }

            Item {
                width: parent.width
                height: Math.round(page.height * 0.4)

                Image {
                    id: preview

                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    // Paperless archives images as PDF, so the original file is
                    // the only preview that decodes here.
                    source: page.isImage() ? "image://paperless/download/" + page.documentId
                                           : "image://paperless/thumb/" + page.documentId
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Medium
                    running: preview.status === Image.Loading
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !page.saving
                    onClicked: page.open(false)
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
                text: page.saving ? qsTr("Downloading…") : qsTr("Tap the preview to open the document")
            }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: Tags.ready && page.tagIds.length > 0

                Repeater {
                    model: page.tagIds

                    Rectangle {
                        height: tagLabel.height + Theme.paddingSmall
                        width: tagLabel.width + 2 * Theme.paddingMedium
                        radius: height / 2
                        color: {
                            var tagColor = Tags.colorFor(modelData)
                            return tagColor !== "" ? tagColor
                                                   : Theme.rgba(Theme.highlightBackgroundColor, 0.3)
                        }

                        Label {
                            id: tagLabel
                            anchors.centerIn: parent
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Tags.textColorFor(modelData) !== "" ? Tags.textColorFor(modelData)
                                                                       : Theme.primaryColor
                            text: Tags.nameFor(modelData)
                        }
                    }
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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.statusMessage !== ""
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: page.statusMessage
            }

            SectionHeader { text: qsTr("Details") }

            DetailItem {
                label: qsTr("Created")
                value: page.formatDate(page.created)
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("Correspondent")
                value: Correspondents.ready && page.correspondentId > 0
                       ? Correspondents.nameFor(page.correspondentId) : ""
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("Type")
                value: {
                    var typeId = page.details.document_type
                    return DocumentTypes.ready && typeId > 0 ? DocumentTypes.nameFor(typeId) : ""
                }
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("Archive serial number")
                value: page.details.archive_serial_number ? String(page.details.archive_serial_number) : ""
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("File")
                value: page.details.original_file_name || ""
                visible: value !== ""
            }

            SectionHeader {
                text: qsTr("Text")
                visible: contentLabel.text !== ""
            }

            Label {
                id: contentLabel

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: text !== ""
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: page.details.content ? String(page.details.content).trim() : ""
            }
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: page.loadingDetails
    }
}
