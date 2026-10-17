import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property int documentId
    property string documentTitle
    property var created
    property int correspondentId: -1
    property var tagIds: []
    property var details: ({
    })
    property bool loadingDetails: true
    property bool saving: false
    // Set only by open(), so a Download that finishes through the same save
    // signals is never taken for a request to open the file.
    property bool openAfterSave: false
    property string statusMessage
    property string errorMessage
    // Paperless keeps the file as it was uploaded and, for most documents, an
    // archived PDF next to it.
    property bool hasArchive: !!details.archived_file_name
    property bool hasOriginal: !!details.original_file_name
    property int noteCount: details.notes ? details.notes.length : 0

    function fileName(original) {
        var name = original ? (details.original_file_name || details.archived_file_name) : (details.archived_file_name || details.original_file_name);
        if (name)
            return name;

        return (documentTitle !== "" ? documentTitle : "paperless-" + documentId) + ".pdf";
    }

    function isImage() {
        var name = (details.original_file_name || "").toLowerCase();
        return /\.(png|jpe?g|gif|webp|bmp|tiff?)$/.test(name);
    }

    function isImagePath(path) {
        return /\.(png|jpe?g|gif|webp|bmp|tiff?)$/.test(String(path).toLowerCase());
    }

    // Writes into ~/Downloads/Paperiton under the server's file name
    // (overwriting if that name is already there), then opens from there:
    // images stay inside Paperiton, everything else goes to the system handler.
    // Without an explicit choice the version that renders best is used: an image
    // shows as an image, while everything else is read from the archived PDF.
    // Only a tap on the preview (or its press-and-hold menu) asks for this.
    function open(original) {
        page.errorMessage = "";
        page.statusMessage = "";
        if (original === undefined)
            original = isImage() || !hasArchive;

        page.openAfterSave = true;
        Paperless.saveDocument(documentId, fileName(original), original);
    }

    // Writes the file into Downloads/Paperiton without opening it, in the same
    // version a preview tap would choose. The run, and its notification, belong
    // to the window, so it carries on if this page is left behind.
    function download() {
        var original = isImage() || !hasArchive;
        app.downloadDocument(documentId, fileName(original), original);
    }

    function view(path) {
        if (isImagePath(path)) {
            pageStack.push(Qt.resolvedUrl("ImageViewPage.qml"), {
                "source": Paperless.fileUrl(path),
                "title": page.documentTitle
            });
            return ;
        }
        Qt.openUrlExternally(Paperless.fileUrl(path));
    }

    function formatDate(value) {
        if (!value || isNaN(value.getTime()))
            return "";

        return Qt.formatDate(value, Qt.DefaultLocaleLongDate);
    }

    allowedOrientations: Orientation.All
    onStatusChanged: {
        if (status === PageStatus.Active && loadingDetails)
            Paperless.fetchDocument(documentId);

    }

    Connections {
        target: Paperless
        onDocumentFetched: {
            if (documentId !== page.documentId)
                return ;

            page.details = document;
            page.loadingDetails = false;
            if (document.title)
                page.documentTitle = document.title;

            if (document.tags)
                page.tagIds = document.tags;

            if (document.correspondent !== undefined && document.correspondent !== null)
                page.correspondentId = document.correspondent;

        }
        onDocumentFetchFailed: {
            if (documentId !== page.documentId)
                return ;

            page.loadingDetails = false;
            page.errorMessage = error;
        }
        // Only a preview open sets openAfterSave. A Download shares the same
        // save signals but reports itself through the window notification, and
        // must not open the file once the run has already cleared app.downloading.
        onDocumentSaveStarted: {
            if (documentId === page.documentId && page.openAfterSave)
                page.saving = true;

        }
        onDocumentSaved: {
            if (documentId !== page.documentId || !page.openAfterSave)
                return ;

            page.openAfterSave = false;
            page.saving = false;
            app.notify(qsTr("%1 was saved in Downloads/Paperiton").arg(filePath.substring(filePath.lastIndexOf("/") + 1)));
            page.view(filePath);
        }
        onDocumentSaveFailed: {
            if (documentId !== page.documentId || !page.openAfterSave)
                return ;

            page.openAfterSave = false;
            page.saving = false;
            page.errorMessage = error;
        }
        onDocumentUpdated: {
            if (documentId !== page.documentId)
                return ;

            page.details = document;
            page.documentTitle = document.title ? document.title : page.documentTitle;
            page.tagIds = document.tags ? document.tags : [];
            page.correspondentId = document.correspondent ? document.correspondent : -1;
            page.created = document.created ? new Date(document.created) : page.created;
            page.statusMessage = qsTr("Changes saved");
        }
        onDocumentUpdateFailed: {
            if (documentId !== page.documentId)
                return ;

            page.errorMessage = error;
        }
        // The document this page is about is no longer there to be shown. The
        // list it came from has already dropped the row.
        onDocumentDeleted: {
            if (documentId === page.documentId)
                pageStack.pop();

        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Delete")
                visible: app.allowed("delete_document")
                onClicked: deleteRemorse.execute(qsTr("Deleting"), function() {
                    Paperless.deleteDocument(page.documentId);
                })
            }

            MenuItem {
                text: qsTr("Edit")
                visible: app.allowed("change_document")
                enabled: !page.loadingDetails
                onClicked: pageStack.push(Qt.resolvedUrl("DocumentEditPage.qml"), {
                    "documentId": page.documentId,
                    "details": page.details,
                    "documentTitle": page.documentTitle,
                    "correspondentId": page.correspondentId,
                    "documentTypeId": page.details.document_type ? page.details.document_type : -1,
                    "tagIds": page.tagIds,
                    "created": page.created
                })
            }

            MenuItem {
                text: qsTr("Download")
                enabled: !page.loadingDetails && !page.saving && !app.downloading
                onClicked: page.download()
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    page.loadingDetails = true;
                    page.errorMessage = "";
                    Paperless.fetchDocument(page.documentId);
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

            // ContextMenu must hang off a ListItem (or an Item whose height
            // grows with the menu). Showing it on a fixed-height BackgroundItem
            // leaves the choices drawn inside the preview instead of on the page.
            ListItem {
                id: previewItem

                width: parent.width
                contentHeight: Math.round(page.height * 0.4)
                enabled: !page.saving
                showMenuOnPressAndHold: page.hasArchive && page.hasOriginal
                onClicked: page.open()

                Image {
                    id: preview

                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    // Paperless archives images as PDF, so the file as it was
                    // uploaded is the only preview that decodes here.
                    source: page.isImage() ? "image://paperless/original/" + page.documentId : "image://paperless/thumb/" + page.documentId
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Medium
                    running: preview.status === Image.Loading
                }

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Open archived PDF")
                        onClicked: page.open(false)
                    }

                    MenuItem {
                        text: qsTr("Open original file")
                        onClicked: page.open(true)
                    }

                }

            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
                text: {
                    if (page.saving)
                        return qsTr("Downloading…");

                    if (page.hasArchive && page.hasOriginal)
                        return qsTr("Tap the preview to open the document, press and hold to " + "choose between the archived PDF and the original file");

                    return qsTr("Tap the preview to open the document");
                }
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
                            var tagColor = Tags.colorFor(modelData);
                            return tagColor !== "" ? tagColor : Theme.rgba(Theme.highlightBackgroundColor, 0.3);
                        }

                        Label {
                            id: tagLabel

                            anchors.centerIn: parent
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Tags.textColorFor(modelData) !== "" ? Tags.textColorFor(modelData) : Theme.primaryColor
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

            BackgroundItem {
                width: parent.width
                enabled: !page.loadingDetails
                onClicked: pageStack.push(Qt.resolvedUrl("NotesPage.qml"), {
                    "documentId": page.documentId,
                    "documentTitle": page.documentTitle
                })

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: page.noteCount > 0 ? qsTr("Notes (%1)").arg(page.noteCount) : qsTr("Notes")
                }

                Image {
                    source: "image://theme/icon-m-right?" + (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)

                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }

                }

            }

            SectionHeader {
                text: qsTr("Details")
            }

            DetailItem {
                label: qsTr("Created")
                value: page.formatDate(page.created)
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("Correspondent")
                value: Correspondents.ready && page.correspondentId > 0 ? Correspondents.nameFor(page.correspondentId) : ""
                visible: value !== ""
            }

            DetailItem {
                label: qsTr("Type")
                value: {
                    var typeId = page.details.document_type;
                    return DocumentTypes.ready && typeId > 0 ? DocumentTypes.nameFor(typeId) : "";
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

        RemorsePopup {
            id: deleteRemorse
        }

        VerticalScrollDecorator {
        }

    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: page.loadingDetails
    }

}
