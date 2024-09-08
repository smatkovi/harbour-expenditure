/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0 as D

import "../components"
import "../js/storage.js" as Storage
import "../js/dates.js" as Dates

Dialog {
    id: root
    allowedOrientations: Orientation.All

    onStatusChanged: {
        // make sure the date is always correct, even if the page has been
        // on the stack for a long time
        if (status !== PageStatus.Activating) return;
        _now = new Date()
        currentDate = _now.toLocaleString(Qt.locale(), Dates.fullDateTimeFormat)
        dbCurrentDate = _now.toLocaleString(Qt.locale(), Dates.dbDateFormat)
        nameField.forceActiveFocus()
    }

    property date _now: new Date()
    property string currentDate: _now.toLocaleString(Qt.locale(), Dates.fullDateTimeFormat);
    property string dbCurrentDate: Qt.formatDateTime(_now, Dates.dbDateFormat)
    property bool editing: rowid > -1

    property int rowid: -1
    property int index: -1
    property var model: null

    property string utc_time: _now.toISOString()
    property string local_time: dbCurrentDate
    property string local_tz: Dates.getTimezone()
    property alias name: nameField.text
    property alias info: infoField.text
    property alias sum: sumField.value
    property alias currency: currencyField.text

    property string payer
    property var beneficiaries: ({})

    onAccepted: {
        if (editing) {
            appWindow.activeProject.updateEntry(
                index, rowid,
                utc_time, local_time, local_tz,
                name, info, sum, currency)
        } else {
            appWindow.activeProject.addEntry(
                utc_time, local_time, local_tz,
                name, info, sum, currency)
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        VerticalScrollDecorator { flickable: flick }

        Column {
            id: content
            width: parent.width
            height: childrenRect.height

            DialogHeader {
                title: editing ? qsTr("Edit expense") : qsTr("New expense")
                acceptText: qsTr("Save")
                cancelText: qsTr("Discard")
            }

            DateTimePickerCombo {
                label: qsTr("Date")
                date: local_time
                timeZone: local_tz
                onDateChanged: {
                    local_time = date
                    utc_time = Dates.parseDate(date).toISOString()
                }
            }

            Item { width: parent.width; height: Theme.paddingMedium }

            TextField {
                id: nameField
                width: parent.width
                acceptableInput: text.length < 300
                label: qsTr("Expense")
                EnterKey.onClicked: sumField.forceActiveFocus()
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                TextField {
                    id: sumField
                    property double value: 0.00

                    width: parent.width / 5 * 3 - parent.spacing
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    label: qsTr("Price")
                    textRightMargin: 0
                    EnterKey.onClicked: focus = false

                    onFocusChanged: {
                        if (focus) {
                            if (value == 0.00) {
                                text = '  %1  '.arg(value.toFixed(2))
                            } else {
                                text = '  %1  '.arg(String(value))
                            }

                            selectAll()
                        } else {
                            if (!!text) {
                                value = Number(text.trim().replace(',', '.'))
                                text = value.toLocaleCurrencyString(Qt.locale('de-CH'), ' ').trim()
                            } else {
                                value = 0.00
                            }
                        }
                    }

                    onValueChanged: {
                        text = value.toLocaleCurrencyString(Qt.locale('de-CH'), ' ').trim()
                    }
                }

                TextField {
                    id: currencyField
                    text: appWindow.activeProject.lastCurrency
                    width: parent.width / 5 * 2
                    acceptableInput: text.length < 100
                    label: qsTr("Currency")
                    EnterKey.onClicked: focus = false
                }
            }

            TextField {
                id: infoField
                width: parent.width
                acceptableInput: text.length < 1000
                label: qsTr("Additional notes")
                EnterKey.onClicked: focus = false
            }

            Row {
                width: parent.width - 2*Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width / 2 - parent.spacing / 2
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.highlightColor
                    text: qsTr("Payer")
                    horizontalAlignment: Text.AlignLeft
                }

                Label {
                    width: parent.width / 2 - parent.spacing / 2
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.highlightColor
                    text: qsTr("Beneficiaries")
                    horizontalAlignment: Text.AlignRight
                }
            }

            D.OneLineDelegate {
                id: allItem

                property bool allSelected: {
                    for (var i in appWindow.activeProject.members) {
                        var member = appWindow.activeProject.members[i]

                        if (!(!!root.beneficiaries[member])) {
                            return false
                        }
                    }

                    return true
                }

                text: qsTr("everyone")
                padding.topBottom: 0

                leftItem: TextSwitch {
                    opacity: 0
                    enabled: false
                    leftMargin: 0
                    rightMargin: 0
                    width: Theme.itemSizeExtraSmall - Theme.paddingMedium
                }
                rightItem: TextSwitch {
                    onClicked: allItem.toggle()
                    highlighted: down
                    checked: allItem.allSelected
                    automaticCheck: false
                    LayoutMirroring.enabled: true
                    LayoutMirroring.childrenInherit: true
                    leftMargin: 0
                    rightMargin: 0
                    width: Theme.itemSizeExtraSmall - Theme.paddingMedium
                }

                function toggle() {
                    if (allSelected) {
                        root.beneficiaries = {}
                    } else {
                        for (var i in appWindow.activeProject.members) {
                            var member = appWindow.activeProject.members[i]
                            root.beneficiaries[member] = true
                        }

                        root.beneficiaries = root.beneficiaries
                    }
                }
            }

            D.DelegateColumn {
                model: appWindow.activeProject.members

                delegate: D.OneLineDelegate {
                    id: item
                    text: modelData
                    textLabel.wrapped: true

                    property bool isPayer: root.payer === modelData
                    property bool isBeneficiary: !!root.beneficiaries[modelData]

                    leftItem: TextSwitch {
                        onClicked: root.payer = modelData
                        highlighted: down || (highlightItem.isHighlighted &&
                                              highlightItem.isLeft)
                        checked: isPayer
                        automaticCheck: false
                        leftMargin: 0
                        rightMargin: 0
                        width: Theme.itemSizeExtraSmall - Theme.paddingMedium
                    }
                    rightItem: TextSwitch {
                        onClicked: {
                            root.beneficiaries[modelData] = !(!!root.beneficiaries[modelData])
                            root.beneficiaries = root.beneficiaries
                        }
                        highlighted: down || (highlightItem.isHighlighted &&
                                              !highlightItem.isLeft)
                        checked: isBeneficiary
                        automaticCheck: false
                        LayoutMirroring.enabled: true
                        LayoutMirroring.childrenInherit: true
                        leftMargin: 0
                        rightMargin: 0
                        width: Theme.itemSizeExtraSmall - Theme.paddingMedium
                    }

                    padding.topBottom: 0
                    contentItem.color: "transparent"

                    Rectangle {
                        id: highlightItem
                        property bool isHighlighted: item._showPress
                        property bool isLeft: x < item.width / 2

                        z: -1000
                        parent: item.contentItem
                        height: parent.height
                        width: parent.width / 2
                        color: item._showPress ? item.highlightedColor : "transparent"
                    }

                    onPressed: {
                        if (mouse.x < item.width / 2) {
                            highlightItem.x = 0
                        } else {
                            highlightItem.x = item.width / 2
                        }
                    }

                    onClicked: {
                        if (mouse.x < item.width / 2) {
                            root.payer = modelData
                        } else {
                            root.beneficiaries[modelData] = !(!!root.beneficiaries[modelData])
                            root.beneficiaries = root.beneficiaries
                        }
                    }
                }

                onClicked: toggle()
            }
        }
    }
}
