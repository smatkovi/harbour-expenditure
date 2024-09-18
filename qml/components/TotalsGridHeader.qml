import QtQuick 2.6
import QtQuick.Layouts 1.1
import Sailfish.Silica 1.0

Label {
    Layout.preferredWidth: parent.width / 4
    Layout.minimumWidth: 0
    Layout.maximumWidth: parent.width / 3
    Layout.fillWidth: true

    wrapMode: Text.Wrap
    font.pixelSize: Theme.fontSizeSmall
    color: Theme.secondaryHighlightColor
    horizontalAlignment: Text.AlignRight
}
