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

    property string lastPayer
    property var lastBeneficiaries: ([])
    property var lastBeneficiariesMap: ({})

    readonly property ListModel expenses: ListModel {}

    function removeEntry(item, ident, index) {
        item.remorseDelete(function() {
            Storage.deleteExpense(root.ident, ident)
            root.expenses.remove(index)
        })
    }

    function reloadMetadata() {
        var metadata = Storage.getProjectMetadata(ident)
        if (metadata === null) return

        name = metadata.name
        baseCurrency = metadata.baseCurrency
        members = metadata.members
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
