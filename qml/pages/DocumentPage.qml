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

    property var pdfComponent: null
    property bool openAfterExport: false

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

    function isImagePath(path) {
        return /\.(png|jpe?g|gif|webp|bmp|tiff?)$/.test(String(path).toLowerCase())
    }

    // Downloads into the private cache, from where only this app can read the
    // file; it is deleted again when the app quits.
    function open(original) {
        page.errorMessage = ""
        page.statusMessage = ""
        Paperless.saveDocument(documentId, fileName(original), original)
    }

    function saveOnDevice() {
        page.errorMessage = ""
        page.statusMessage = ""

        var dialog = pageStack.push(Qt.resolvedUrl("SavePage.qml"), {
                                        archivedName: fileName(false),
                                        originalName: details.original_file_name
                                                      ? details.original_file_name : ""
                                    })
        dialog.accepted.connect(function() {
            Paperless.exportDocument(page.documentId, dialog.fileName, dialog.original,
                                     dialog.destination)
        })
    }

    function view(path) {
        if (isImagePath(path)) {
            pageStack.push(Qt.resolvedUrl("ImageViewPage.qml"), {
                               source: Paperless.fileUrl(path),
                               title: page.documentTitle
                           })
            return
        }

        if (page.pdfComponent === null)
            page.pdfComponent = Qt.createComponent(Qt.resolvedUrl("PdfViewPage.qml"))

        if (page.pdfComponent.status === Component.Ready) {
            pageStack.push(page.pdfComponent, {
                               source: Paperless.fileUrl(path),
                               title: page.documentTitle
                           })
            return
        }

        // Without the system viewer the file has to leave the sandbox, because
        // no other app can read the cache directory.
        page.statusMessage = qsTr("Opening in another app")
        page.openAfterExport = true
        Paperless.exportDocument(documentId, fileName(true), true)
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
            page.view(filePath)
        }

        onDocumentExported: {
            if (documentId !== page.documentId)
                return
            page.saving = false
            page.statusMessage = qsTr("Saved to %1").arg(filePath)
            if (page.openAfterExport) {
                page.openAfterExport = false
                Qt.openUrlExternally(Paperless.fileUrl(filePath))
            }
        }

        onDocumentSaveFailed: {
            if (documentId !== page.documentId)
                return
            page.saving = false
            page.openAfterExport = false
            page.errorMessage = error
        }

        onDocumentUpdated: {
            if (documentId !== page.documentId)
                return
            page.details = document
            page.documentTitle = document.title ? document.title : page.documentTitle
            page.tagIds = document.tags ? document.tags : []
            page.correspondentId = document.correspondent ? document.correspondent : -1
            page.created = document.created ? new Date(document.created) : page.created
            page.statusMessage = qsTr("Changes saved")
        }

        onDocumentUpdateFailed: {
            if (documentId !== page.documentId)
                return
            page.errorMessage = error
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Notes")
                onClicked: pageStack.push(Qt.resolvedUrl("NotesPage.qml"), {
                                              documentId: page.documentId,
                                              documentTitle: page.documentTitle
                                          })
            }

            MenuItem {
                text: qsTr("Edit")
                visible: app.allowed("change_document")
                enabled: !page.loadingDetails
                onClicked: pageStack.push(Qt.resolvedUrl("DocumentEditPage.qml"), {
                                              documentId: page.documentId,
                                              details: page.details,
                                              documentTitle: page.documentTitle,
                                              correspondentId: page.correspondentId,
                                              documentTypeId: page.details.document_type
                                                              ? page.details.document_type : -1,
                                              tagIds: page.tagIds,
                                              created: page.created
                                          })
            }

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
                text: qsTr("Save on device")
                enabled: !page.saving && !page.loadingDetails
                onClicked: page.saveOnDevice()
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
