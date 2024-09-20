/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0 as D
import Opal.MenuSwitch 1.0 as M

import "../enums"
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
        _nowLocalTime = _now.toLocaleString(Qt.locale(), Dates.dbDateFormat)
        _nowUtc = _now.toISOString()

        if (!_editing) {
            nameField.forceActiveFocus()
        }
    }

    property date _now: new Date()
    property string _nowLocalTime: Qt.formatDateTime(_now, Dates.dbDateFormat)
    property string _nowUtc: _now.toISOString()

    property bool _editing: rowid > -1
    property bool _usingCustomTime: false
    property bool _customExchangeRate: appWindow.activeProject.ratesMode === RatesMode.perTransaction || !isNaN(rate)
    property bool _customFees: appWindow.activeProject.feesMode === FeesMode.shownByDefault || !isNaN(percentageFees) || !isNaN(fixedFees)
    property var initialValuesReadOnly: ({})

    property int rowid: -1
    property int index: -1

    property string utc_time: _nowUtc
    property string local_time: _nowLocalTime
    property string local_tz: Dates.getTimezone()
    property alias name: nameField.text
    property alias info: infoField.text
    property alias sum: sumField.value
    property alias currency: currencyField.text
    property alias rate: rateField.value
    property alias percentageFees: percentageFeeField.value
    property alias fixedFees: fixedFeeField.value

    property string payer: appWindow.activeProject.lastPayer
    property string initialBeneficiaries: Storage.joinMembersList(appWindow.activeProject.lastBeneficiaries)
    property var _mergedMembers: {
        // This is an array containing all active members of the project
        // plus possible additional members that were deleted from the
        // project but are still stored in this expense entry.
        // This is only relevant when editing entries after a member has
        // been deleted from the project.
        var members = appWindow.activeProject.members
        var extras = Storage.splitMembersList(initialBeneficiaries)

        if (extras.indexOf(payer) < 0) {
            extras.push(payer)
        }

        return members.concat(extras.filter(
            function(item){ return !!item && members.indexOf(item) < 0 }))
    }

    property var beneficiaries: {
        var map = {}
        var initial = Storage.splitMembersList(initialBeneficiaries)

        for (var i in _mergedMembers) {
            map[_mergedMembers[i]] = false
        }

        for (var k in initial) {
            map[initial[k]] = true
        }

        return map
    }

    function _getBeneficiariesArray() {
        var array = []

        for (var i in _mergedMembers) {
            var member = _mergedMembers[i]

            if (!!root.beneficiaries[member]) {
                array.push(member)
            }
        }

        return array
    }

    canAccept: {
        !!name.trim() && !!currency.trim()
        && !!payer.trim() && _getBeneficiariesArray().length > 0
    }

    onAccepted: {
        var beneficiaries = _getBeneficiariesArray()
        var name = root.name.trim()
        var info = root.info.trim()
        var currency = root.currency.trim()

        if (_editing) {
            appWindow.activeProject.updateEntry(
                index, rowid,
                utc_time, local_time, local_tz,
                name, info, sum, currency,
                rate, percentageFees, fixedFees,
                payer, beneficiaries,
                _usingCustomTime)
        } else {
            appWindow.activeProject.addEntry(
                utc_time, local_time, local_tz,
                name, info, sum, currency,
                rate, percentageFees, fixedFees,
                payer, beneficiaries,
                _usingCustomTime)
        }
    }

    onDone: {
        // Do nothing else if the dialog was accepted.
        if (result != DialogResult.Rejected && result != DialogResult.None) {
            return
        }

        // Do nothing else if no relevant data has been entered.
        // Rates, fees, and beneficiaries are ignored here, and that is ok.
        var changed = false

        if (name == "" && info == "" && sum === 0.00
            && (currency == "" ||
                currency == appWindow.activeProject.lastCurrency)) {
            return
        } else if (!_editing) {
            changed = true
        }

        // Check if any field has been changed. If so, save it, and show
        // a remorse timer to allow reopening the rejected dialog.
        // The check is not 100% thorough but it is close enough.
        var properties = [
            "index", "rowid", "utc_time", "local_time",
            "local_tz", "name", "info", "sum",
            "rate", "percentageFees", "fixedFees",
            "currency", "payer", "beneficiaries"]
        appWindow._currentlyEditedEntry['initialValuesReadOnly'] = initialValuesReadOnly

        for (var i in properties) {
            var prop = properties[i]
            appWindow._currentlyEditedEntry[prop] = root[prop]

            if (initialValuesReadOnly.hasOwnProperty(prop) &&
                    !Storage.isSameValue(root[prop], initialValuesReadOnly[prop])) {
                changed = true
                console.log("field changed:", prop)
            }
        }

        if (!changed) {
            return
        }

        try {
            var page = pageStack.previousPage(page)
        } catch(error) {
            page = appWindow
        }

        if (_editing) {
            remorseCancelWriting(page || appWindow, qsTr("Discarded all changes"))
        } else {
            remorseCancelWriting(page || appWindow, qsTr("Discarded the entry"))
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        VerticalScrollDecorator { flickable: flick }

        PullDownMenu {
            M.MenuSwitch {
                text: qsTr("Add fees")
                checked: _customFees
                automaticCheck: false
                onClicked: {
                    if (_customFees) { // reset
                        _customFees = true // break binding
                        percentageFees = NaN
                        fixedFees = NaN
                    }
                    _customFees = !_customFees
                }
            }
            M.MenuSwitch {
                text: qsTr("Custom exchange rate")
                checked: _customExchangeRate
                automaticCheck: false
                onClicked: {
                    if (_customExchangeRate) { // reset
                        _customExchangeRate = true // break binding
                        rate = NaN
                    }
                    _customExchangeRate = !_customExchangeRate
                }
            }
        }

        Column {
            id: content
            width: parent.width
            height: childrenRect.height

            DialogHeader {
                title: _editing ? qsTr("Edit expense") : qsTr("New expense")
                acceptText: qsTr("Save")
                cancelText: qsTr("Discard")
            }

            DateTimePickerCombo {
                label: qsTr("Date")
                date: local_time
                timeZone: local_tz
                onDateChanged: {
                    if (date == local_time) {
                        return
                    }

                    _usingCustomTime = true
                    local_time = date
                    utc_time = Dates.parseDate(date).toISOString()
                }
            }

            Spacer { size: Theme.paddingMedium }

            TextField {
                id: nameField
                width: parent.width
                acceptableInput: text.length < 300
                label: qsTr("Expense")
                EnterKey.onClicked: sumField.forceActiveFocus()
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                CurrencyInputField {
                    id: sumField
                    label: qsTr("Price")
                    width: parent.width / 5 * 3 - parent.spacing
                    textRightMargin: 0
                    allowNull: true
                    emptyValue: 0.00

                    EnterKey.iconSource: {
                        if (_customExchangeRate || _customFees) {
                            "image://theme/icon-m-enter-next"
                        } else {
                            "image://theme/icon-m-enter-close"
                        }
                    }
                    EnterKey.onClicked: {
                        if (_customExchangeRate) {
                            rateField.forceActiveFocus()
                        } else if (_customFees) {
                            percentageFeeField.forceActiveFocus()
                        } else {
                            focus = false
                        }
                    }
                }

                TextField {
                    id: currencyField
                    text: appWindow.activeProject.lastCurrency
                    width: parent.width / 5 * 2
                    acceptableInput: text.length < 100
                    label: qsTr("Currency")
                    inputMethodHints: Qt.ImhNoPredictiveText
                    onFocusChanged: if (focus) selectAll()

                    EnterKey.iconSource: {
                        if (_customExchangeRate || _customFees) {
                            "image://theme/icon-m-enter-next"
                        } else {
                            "image://theme/icon-m-enter-close"
                        }
                    }
                    EnterKey.onClicked: {
                        if (_customExchangeRate) {
                            rateField.forceActiveFocus()
                        } else if (_customFees) {
                            percentageFeeField.forceActiveFocus()
                        } else {
                            focus = false
                        }
                    }
                }
            }

            TextField {
                id: infoField
                width: parent.width
                acceptableInput: text.length < 1000
                label: qsTr("Additional notes")
                EnterKey.onClicked: focus = false
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
            }

            EditableRatesListDelegate {
                id: rateField
                visible: _customExchangeRate
                project: ProjectData {
                    // cannot assing appWindow.activeProject, but why?
                    rowid: appWindow.activeProject.rowid
                    loadExpenses: false
                    loadRates: true
                }
                currency: currencyField.text
                foreignSum: sumField.value
                allowEmpty: true
                emptyValue: NaN
                value: emptyValue
                placeholder: project.exchangeRates[currency] || ''

                EnterKey.iconSource: {
                    if (_customFees) {
                        "image://theme/icon-m-enter-next"
                    } else {
                        "image://theme/icon-m-enter-close"
                    }
                }
                EnterKey.onClicked: {
                    if (_customFees) {
                        percentageFeeField.forceActiveFocus()
                    } else {
                        focus = false
                    }
                }
            }

            Spacer {
                size: Theme.paddingLarge
                visible: _customExchangeRate && !_customFees
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: _customFees

                // TODO load last used values for the current payer

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

            Spacer { size: Theme.paddingMedium }

            // TODO add "personal account" special item below allItem
            //      Users can exchange cash and enter it into their
            //      "personal account" with the actually used exchange rate
            //      and any fees. This is then used to calculate the
            //      effective exchange rate when the money is being used.

            D.OneLineDelegate {
                id: allItem

                property bool allSelected: {
                    for (var i in _mergedMembers) {
                        var member = _mergedMembers[i]

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
                        for (var i in _mergedMembers) {
                            root.beneficiaries[_mergedMembers[i]] = true
                        }

                        root.beneficiaries = root.beneficiaries
                    }
                }

                onClicked: toggle()
            }

            D.DelegateColumn {
                model: _mergedMembers

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
            }
        }
    }
}
