/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

import "../js/dates.js" as Dates
import "../js/storage.js" as Storage

ListItem {
    id: item

    property ProjectData project
    signal rateUpdated(var value)
    signal fixedFeesUpdated(var value)
    signal percentageFeesUpdated(var value)

    contentHeight: Theme.itemSizeMedium
                   + Theme.itemSizeSmall
                   + Theme.itemSizeSmall
                   + 2*Theme.paddingMedium
    height: column.height
    width: root.width
    _backgroundColor: "transparent"
    highlighted: false

    readonly property int _index: index
    readonly property int _rowid: rowid
    readonly property string _date: Dates.formatDate(local_time, Dates.timeFormat, local_tz)

    readonly property string _currency: currency
    readonly property double _sum: sum
    readonly property string _payer: payer
    readonly property string _title: name

    readonly property double _rate: rate
    readonly property double _fixedFees: fixed_fees
    readonly property double _percentageFees: percentage_fees

    Column {
        id: column
        width: parent.width
        height: childrenRect.height

        TwoLineDelegate {
            text: item._date
            description: "%1: %2".arg(item._payer).arg(item._title)
            interactive: false

            onClicked: toggleWrappedText(descriptionLabel)

            textLabel {
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
            }
            descriptionLabel {
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.highlightColor
            }

            rightItem: DelegateInfoItem {
                text: Number(sum).toLocaleString(Qt.locale('de_CH'))
                description: currency
                alignment: Qt.AlignRight

                textLabel {
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.highlightColor
                }
                descriptionLabel {
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryHighlightColor
                }
            }
        }

        EditableRatesListDelegate {
            id: ratesItem
            project: item.project
            currency: item._currency
            foreignSum: item._sum
            allowEmpty: true
            emptyValue: NaN
            value: item._rate
            placeholder: project.exchangeRates[currency] || ''
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: feesItem.forceActiveFocus()

            onValueChanged: {
                if (!Storage.isSameValue(value, item._rate)) {
                    project.expenses.set(_index, {'rate': value})
                    rateUpdated(value)
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.itemSizeSmall + 2*Theme.paddingMedium

            FeesItem {
                id: feesItem
                anchors.verticalCenter: parent.verticalCenter
                percentageFees: item._percentageFees
                fixedFees: item._fixedFees

                onPercentageFeesChanged: {
                    if (!Storage.isSameValue(percentageFees, item._percentageFees)) {
                        project.expenses.set(_index, {'percentage_fees': percentageFees})
                        percentageFeesUpdated(percentageFees)
                    }
                }
                onFixedFeesChanged: {
                    if (!Storage.isSameValue(fixedFees, item._fixedFees)) {
                        project.expenses.set(_index, {'fixed_fees': fixedFees})
                        fixedFeesUpdated(fixedFees)
                    }
                }
            }
        }
    }
}
