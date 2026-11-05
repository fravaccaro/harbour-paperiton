import QtQuick 2.0
import Sailfish.Silica 1.0

// The word under a number, saying what it counts.
Label {
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Theme.secondaryColor
    font.pixelSize: Theme.fontSizeExtraSmall
}
