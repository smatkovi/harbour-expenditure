import QtQuick 2.6
import Sailfish.Silica 1.0

Label {
    width: parent.width - 2*x
    x: Theme.horizontalPageMargin
    wrapMode: Text.Wrap
    color: Theme.secondaryHighlightColor
    font.pixelSize: Theme.fontSizeExtraSmall
}
