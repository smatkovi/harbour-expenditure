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
    readonly property bool active: project_id_timestamp !== 0

    property double project_id_timestamp
    property string name
    property string baseCurrency
    property var members: ([])

    property string lastCurrency
    property string lastPayer
    property var lastBeneficiaries: ([])
    property var lastBeneficiariesMap: ({})

    readonly property ListModel expenses: ListModel {}

    signal loaded(var project_id_timestamp)

    function removeEntry(item, rowid, index) {
        item.remorseDelete(function() {
            Storage.deleteExpense(root.project_id_timestamp, rowid)
            root.expenses.remove(index)
        })
    }

    function addEntry(utc_time, local_time, local_tz,
                      name, info, sum, currency, payer, beneficiaries,
                      reload) {
        var newEntry = Storage.addExpense(
            project_id_timestamp,
            utc_time, local_time, local_tz,
            name, info, sum, currency, payer, beneficiaries)

        if (reload) {
            reloadContents()
        } else if (Storage.getSortOrder() === 'DESC') {
            expenses.insert(0, newEntry)
        } else {
            expenses.append(newEntry)
        }
    }

    function updateEntry(index, rowid,
                         utc_time, local_time, local_tz,
                         name, info, sum, currency, payer, beneficiaries,
                         reload) {
        var changedEntry = Storage.updateExpense(
            project_id_timestamp, rowid,
            utc_time, local_time, local_tz,
            name, info, sum, currency, payer, beneficiaries)

        if (reload) {
            reloadContents()
        } else {
            expenses.set(index, changedEntry)
        }
    }

    function reloadMetadata() {
        var metadata = Storage.getProjectMetadata(project_id_timestamp)
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
        expenses.append(Storage.getProjectEntries(project_id_timestamp))
    }

    onProject_id_timestampChanged: {
        if (project_id_timestamp === 0) {
            name = ''
            currency = ''
            members = []
            expenses.clear()
            return
        }

        reloadMetadata()
        reloadContents()

        console.log("loaded project data:", project_id_timestamp, name, members)
        loaded(project_id_timestamp)
    }
}
