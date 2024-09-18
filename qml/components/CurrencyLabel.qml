import QtQuick 2.6
import QtQuick.Layouts 1.1
import Sailfish.Silica 1.0
import Sailfish.Share 1.0

import "../js/storage.js" as Storage

Label {
    property real value: 0.00
    property bool asSaldo: false

    property color _neutralColor: Theme.primaryColor
    property color _zeroColor: Theme.secondaryColor
    property color _positiveColor: Theme.colorScheme == Theme.LightOnDark ?
                                       Qt.lighter("darkgreen", 1.8) : "darkgreen"
    property color _negativeColor: Theme.colorScheme == Theme.LightOnDark ?
                                       Theme.rgba("red", 0.9) : "red"
    property string _valueText: {
        if (value == 0) Number(0).toFixed(2)
        else if (value < 0) "- " + Number(Math.abs(value)).toFixed(2)
        else (asSaldo ? "+ " : "") + Number(value).toFixed(2)
    }
    property color _valueColor: {
        if (value == 0) _zeroColor
        else if (!asSaldo || (asSaldo && value == 0)) _neutralColor
        else if (value > 0) _positiveColor
        else _negativeColor
    }

    Layout.preferredWidth: parent.width / 4
    Layout.maximumWidth: parent.width / 3
    Layout.minimumWidth: 0
    Layout.fillWidth: true

    wrapMode: Text.Wrap
    font.pixelSize: Theme.fontSizeSmall
    horizontalAlignment: Text.AlignRight

    color: _valueColor
    text: _valueText
}
