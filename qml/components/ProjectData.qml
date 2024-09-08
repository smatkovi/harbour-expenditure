/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/storage.js" as Storage

QtObject {
    id: root
    readonly property bool active: ident !== 0

    property double ident
    property string name
    property string baseCurrency
    property var members: ([])

    property string lastCurrency
    property string lastPayer
    property var lastBeneficiaries: ([])
    property var lastBeneficiariesMap: ({})

    readonly property ListModel expenses: ListModel {}

    function removeEntry(item, rowid, index) {
        item.remorseDelete(function() {
            Storage.deleteExpense(root.ident, rowid)
            root.expenses.remove(index)
        })
    }

    function addEntry(utc_time, local_time, local_tz,
                      name, info, sum, currency) {
        reloadContents()
//    property string section_string: Dates.formatDate(local_time, 'yyyy-MM-dd')
    }

    function updateEntry(index, rowid,
                         utc_time, local_time, local_tz,
                         name, info, sum, currency) {
        reloadContents()
    }

    function reloadMetadata() {
        var metadata = Storage.getProjectMetadata(ident)
        if (metadata === null) return

        name = metadata.name
        baseCurrency = metadata.baseCurrency
        members = metadata.members
        lastCurrency = metadata.lastCurrency
        lastPayer = metadata.lastPayer
        lastBeneficiaries = metadata.lastBeneficiaries

        var map = {}
        for (var i in lastBeneficiaries) {
            map[lastBeneficiaries[i]] = true
        }

        lastBeneficiariesMap = map
    }

    function reloadContents() {
        expenses.clear()
        expenses.append(Storage.getProjectEntries(ident))
    }

    onIdentChanged: {
        if (ident === 0) {
            name = ''
            currency = ''
            members = []
            expenses.clear()
            return
        }

        reloadMetadata()
        reloadContents()

        console.log("loaded project data:", ident, name, members)
    }
}
