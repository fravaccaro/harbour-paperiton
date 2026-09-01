import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    // A LookupModel: Tags, Correspondents or DocumentTypes.
    property QtObject lookup
    property string heading
    property bool multiple: false
    property int selectedId: -1
    property var selectedIds: []

    allowedOrientations: Orientation.All

    function isSelected(itemId) {
        return multiple ? selectedIds.indexOf(itemId) >= 0 : selectedId === itemId
    }

    function toggle(itemId) {
        var ids = selectedIds.slice()
        var at = ids.indexOf(itemId)
        if (at >= 0)
            ids.splice(at, 1)
        else
            ids.push(itemId)
        selectedIds = ids
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: dialog.lookup

        header: Column {
            width: listView.width

            DialogHeader {
                title: dialog.heading
                acceptText: qsTr("Done")
            }

            BackgroundItem {
                width: parent.width
                visible: !dialog.multiple

                onClicked: {
                    dialog.selectedId = -1
                    dialog.accept()
                }

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("None")
                    color: dialog.selectedId <= 0 ? Theme.highlightColor : Theme.primaryColor
                }
            }
        }

        delegate: BackgroundItem {
            id: item

            width: listView.width

            onClicked: {
                if (dialog.multiple) {
                    dialog.toggle(model.itemId)
                } else {
                    dialog.selectedId = model.itemId
                    dialog.accept()
                }
            }

            Row {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMedium

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.paddingMedium
                    height: width
                    radius: width / 2
                    visible: model.color !== ""
                    color: model.color !== "" ? model.color : "transparent"
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - selectedIcon.width - Theme.paddingMedium
                    truncationMode: TruncationMode.Fade
                    text: model.name
                    color: dialog.isSelected(model.itemId) ? Theme.highlightColor
                                                           : (item.highlighted ? Theme.highlightColor
                                                                               : Theme.primaryColor)
                }

                Image {
                    id: selectedIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: dialog.multiple && dialog.isSelected(model.itemId)
                    source: "image://theme/icon-s-installed?" + Theme.highlightColor
                }
            }
        }

        ViewPlaceholder {
            enabled: dialog.lookup && dialog.lookup.count === 0 && !dialog.lookup.loading
            text: qsTr("Nothing to choose from")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: dialog.lookup && dialog.lookup.loading && dialog.lookup.count === 0
    }
}
