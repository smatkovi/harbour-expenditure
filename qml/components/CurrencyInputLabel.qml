import QtQuick 2.6
import Sailfish.Silica 1.0

Label {
    minimumPixelSize: Theme.fontSizeTiny
    fontSizeMode: Text.Fit
    truncationMode: TruncationMode.Fade
    anchors {
        baseline: parent.verticalCenter
        baselineOffset: -Theme.paddingMedium
    }
}
