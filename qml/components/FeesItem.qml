/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0

Row {
    id: root

    property alias percentageFees: percentageFeeField.value
    property alias fixedFees: fixedFeeField.value

    width: parent.width
    spacing: Theme.paddingMedium

    onFocusChanged: {
        if (focus) percentageFeeField.focus = true
    }

    CurrencyInputField {
        id: percentageFeeField
        label: qsTr("Fees")
        emptyValue: NaN
        precision: 4
        width: parent.width / 6 * 2
        textRightMargin: 0
        EnterKey.iconSource: "image://theme/icon-m-enter-next"
        EnterKey.onClicked: fixedFeeField.forceActiveFocus()
    }

    CurrencyInputLabel {
        width: parent.width / 6 * 1 - 3*parent.spacing
        text: "% +"
    }

    CurrencyInputField {
        id: fixedFeeField
        label: qsTr("Fees")
        emptyValue: NaN
        width: parent.width / 6 * 2
        textRightMargin: 0
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: focus = false
    }

    CurrencyInputLabel {
        width: parent.width / 6 * 1
        text: appWindow.activeProject.baseCurrency
    }
}
