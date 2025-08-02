/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

import "../js/math.js" as M

PaddedDelegate {
    id: root
    property ProjectData project

    property string currency
    property alias allowEmpty: _inputField.allowEmpty
    property alias emptyValue: _inputField.emptyValue
    property string foreignSum: ''
    property string placeholder: ''

    property alias inputField: _inputField

    // effective value is: X base currency = 1.00 foreign currency (B2F)
    property string fallback: {
        if (currency === project.baseCurrency) '1.00'
        else project.exchangeRates[currency] || ''
    }
    property string value: emptyValue

    property string _one: M.format('1.00', 2)
    property string _displayType: 'B2F'
    property string _displayDescription: "%1 = %3 %2".
        arg(project.baseCurrency).arg(currency).arg(_one)

    function isEmpty() {
        return _inputField.isEmpty()
    }

    minContentHeight: Theme.itemSizeSmall
    centeredContainer: contentContainer
    interactive: true
    padding.topBottom: 0
    contentItem.color: "transparent"
    onClicked: openMenu()
    enabled: currency !== project.baseCurrency

    menu: ContextMenu {
        MenuItem {
            text: "%1 = %3 %2".arg(project.baseCurrency)
                              .arg(currency)
                              .arg(_one)
            onClicked: {
                root._displayType = 'B2F'
                _inputField.value = value
                root._displayDescription = Qt.binding(function(){return text})
            }
        }
        MenuItem {
            text: "%1 = %3 %2".arg(currency)
                              .arg(project.baseCurrency)
                              .arg(_one)
            onClicked: {
                root._displayType = 'F2B'
                _inputField.value = M.value(value).gt(0) ? M.value(1).div(value).toString() : emptyValue
                root._displayDescription = Qt.binding(function(){ return text })
            }
        }
        MenuItem {
            visible: !M.isNotNum(foreignSum)
            text: qsTr("%1 paid", "as in “I paid 10 USD that were converted to 7 GBP”, " +
                       "with %1 being a currency symbol like 'USD'").arg(project.baseCurrency)
            onClicked: {
                root._displayType = 'paid'
                _inputField.value = M.value(value).gt(0) ? M.value(foreignSum).times(value).toString() : emptyValue
                root._displayDescription = Qt.binding(function(){ return text })
            }
        }
    }

    Rectangle {
        id: highlightItem
        z: -1000
        anchors.right: parent.right
        parent: root.contentItem
        height: parent.height
        width: parent.width / 2
        color: root._showPress ? root.highlightedColor : "transparent"
    }

    Column {
        id: contentContainer
        width: root.width - 2*Theme.horizontalPageMargin

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            CurrencyInputField {
                id: _inputField
                readOnly: !root.enabled
                width: parent.width / 2 - parent.spacing
                label: qsTr("Exchange rate")
                labelVisible: false
                emptyValue: ''
                allowEmpty: false
                allowNull: false
                precision: 4
                value: root.value || root.emptyValue
                textRightMargin: 0
                textMargin: 0
                textTopPadding: Theme.paddingMedium

                Binding on errorHighlight {
                    when: !_inputField.allowEmpty &&
                          !_inputField.acceptableInput
                    value: true
                }

                Component.onCompleted: value = root.value || root.emptyValue

                placeholderText: {
                    if (M.isNotNum(root.placeholder)
                        || M.value(root.placeholder).lte(0)) {
                        console.log("EYYYY", root.placeholder)
                        ""
                    } else if (_displayType === 'B2F') {
                        M.format(root.placeholder, precision)
                    } else if (_displayType === 'F2B') {
                        M.format(M.value(1).div(root.placeholder).toString(), precision)
                    } else if (_displayType === 'paid') {
                        M.format(M.value(foreignSum).times(root.placeholder).toString(), precision)
                    }
                }

                onValueChanged: {
                    var newValue = emptyValue

                    if (_displayType === 'B2F') {
                        newValue = _inputField.value
                    } else if (_displayType === 'F2B') {
                        newValue = M.value(value).gt(0) ?
                            M.value(1).div(_inputField.value).toString() :
                            emptyValue
                    } else if (_displayType === 'paid') {
                        newValue = M.value(value).gt(0) ?
                            M.value(_inputField.value).div(foreignSum).toString() :
                            emptyValue
                    }

                    if (!M.value(newValue).eq(root.value)) {
                        root.value = newValue // avoid a binding loop
                    }
                }
            }

            Label {
                width: parent.width / 2
                height: parent.height
                leftPadding: parent.spacing
                rightPadding: Theme.horizontalPageMargin
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                truncationMode: TruncationMode.Fade
                text: _displayDescription
            }
        }
    }
}
