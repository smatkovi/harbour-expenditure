/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

import "../js/dates.js" as Dates
import "../js/math.js" as M

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
    readonly property string _sum: sum
    readonly property string _payer: payer
    readonly property string _title: name
    readonly property string _beneficiaries_string: beneficiaries_string
    readonly property var _beneficiaries_list: beneficiaries_list

    readonly property string _rate: rate
    readonly property string _fixedFees: fixed_fees
    readonly property string _percentageFees: percentage_fees

    Column {
        id: column
        width: parent.width
        height: childrenRect.height

        ThreeLineDelegate {
            title: item._date
            text: item._title
            description: qsTr(
                 "for %1", "as in “this payment was for Jane, John, and Jim”, " +
                 "with plural based on the number of beneficiaries",
                 item._beneficiaries_list.count).arg(item._beneficiaries_string)

            interactive: false

            onClicked: toggleWrappedText(descriptionLabel)

            titleLabel {
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
            }
            textLabel {
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.highlightColor
            }
            descriptionLabel {
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
            }

            rightItem: DelegateInfoItem {
                title: payer
                text: M.format(sum)
                description: currency
                alignment: Qt.AlignRight

                titleLabel {
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryHighlightColor
                }
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
            emptyValue: ''
            value: item._rate
            placeholder: project.exchangeRates[currency] || '1.00'
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: feesItem.forceActiveFocus()

            onValueChanged: {
                if (!M.value(value).eq(item._rate)) {
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
                    if (!M.value(percentageFees).eq(item._percentageFees)) {
                        project.expenses.set(_index, {'percentage_fees': percentageFees})
                        percentageFeesUpdated(percentageFees)
                    }
                }
                onFixedFeesChanged: {
                    if (!M.value(fixedFees).eq(item._fixedFees)) {
                        project.expenses.set(_index, {'fixed_fees': fixedFees})
                        fixedFeesUpdated(fixedFees)
                    }
                }
            }
        }
    }
}
