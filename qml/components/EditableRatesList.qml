/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Opal.Delegates 1.0

import "../js/math.js" as M

DelegateColumn {
    id: root
    property ProjectData selectedProject
    readonly property int count: selectedProject.currencies.length
    signal exchangeRateChanged(var rate, var currency)

    onExchangeRateChanged: {
        selectedProject.exchangeRates[currency] = rate
    }

    model: selectedProject.currencies
    width: parent.width

    delegate: EditableRatesListDelegate {
        id: delegate
        placeholder: "1.00"
        allowEmpty: false
        project: selectedProject
        currency: modelData
        value: fallback
        onValueChanged: {
            if (!M.isNotNum(value) && value !== emptyValue) {
                root.exchangeRateChanged(value, currency)
            }
        }
    }
}
