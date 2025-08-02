/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import "."  // shadow Silica's InfoLabel

Column {
    width: parent.width
    property alias value: slider.value

    SectionHeader {
        text: qsTr("Decimal precision")
    }

    Slider {
        id: slider
        width: parent.width
        label: qsTr("Decimal precision")
        value: appWindow.activeProject.precision
        valueText: value
        maximumValue: 15
        minimumValue: 0
        stepSize: 1

        onValueChanged: {
            // TODO save value
            appWindow.activeProject.precision = value
        }
    }

    InfoLabel {
        text: qsTr("Results are rounded to this number " +
                   "of decimal places. Set this to a value that makes " +
                   "sense with your currency.")
    }
}
