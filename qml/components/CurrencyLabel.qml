/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 Mirian Margiani
 */

import QtQuick 2.6
import QtQuick.Layouts 1.1
import Sailfish.Silica 1.0
import Sailfish.Share 1.0

import "../js/math.js" as M

Label {
    property string value: '0.00'
    property bool asBalance: false
    property int precision: 2

    property color _neutralColor: Theme.primaryColor
    property color _zeroColor: Theme.secondaryColor
    property color _positiveColor: Theme.colorScheme == Theme.LightOnDark ?
                                       Qt.lighter("darkgreen", 1.8) : "darkgreen"
    property color _negativeColor: Theme.colorScheme == Theme.LightOnDark ?
                                       Theme.rgba("red", 0.9) : "red"
    property var _valueObj: M.value(value)
    property string _valueText: {
        var ret = M.format(_valueObj.abs(), precision)

        if (_valueObj.lt(0)) {
            ret = "- " + ret
        } else if (asBalance && _valueObj.gt(0)) {
            ret = "+ " + ret
        }

        return ret
    }
    property color _valueColor: {
        if (_valueObj.isZero()) _zeroColor
        else if (!asBalance || (asBalance && _valueObj.eq(0))) _neutralColor
        else if (_valueObj.gt(0)) _positiveColor
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
