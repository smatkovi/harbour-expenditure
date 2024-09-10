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

    // STATE
    readonly property bool active: rowid >= 0
    signal loaded(var rowid)

    // CONFIGURATION
    property bool loadExpenses: true
    property var removedMembers: ([])
    property var addedMembers: ([])
    property var renamedMembers: ({})

    // PROJECT METADATA AND DATA
    // ident -1 is reserved for unsaved new projects
    //     < -1 clears all loaded data
    property int rowid
    property string name
    property string baseCurrency
    property var members: ([])
    property string lastCurrency
    property string lastPayer
    property var lastBeneficiaries: ([])
    property int ratesMode: 0
    readonly property ListModel expenses: ListModel {}

    // IMMEDIATELY APPLIED FUNCTIONS
    function removeEntry(item, rowid, index) {
        item.remorseDelete(function() {
            Storage.deleteExpense(root.rowid, rowid)
            root.expenses.remove(index)
        })
    }

    function addEntry(utc_time, local_time, local_tz,
                      name, info, sum, currency, payer, beneficiaries,
                      reload) {
        var newEntry = Storage.addExpense(
            root.rowid,
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
            root.rowid, rowid,
            utc_time, local_time, local_tz,
            name, info, sum, currency, payer, beneficiaries)

        if (reload) {
            reloadContents()
        } else {
            expenses.set(index, changedEntry)
        }
    }

    function reloadMetadata() {
        var metadata = Storage.getProjectMetadata(rowid)
        if (metadata === null) return

        name = metadata.name
        baseCurrency = metadata.baseCurrency
        members = metadata.members
        lastCurrency = metadata.lastCurrency || metadata.baseCurrency
        lastPayer = metadata.lastPayer || ''
        lastBeneficiaries = metadata.lastBeneficiaries
        ratesMode = metadata.ratesMode
    }

    function reloadContents() {
        expenses.clear()
        expenses.append(Storage.getProjectEntries(rowid))
    }

    // FUNCTIONS APPLIED ONCE saveMetadata() IS CALLED
    function removeMember(name) {
        removedMembers.push(name)
        members = members.filter(function(item) {
            return item !== name
        })
    }

    function addMember(name) {
        addedMembers.push(name)
        members = members.concat([name])
    }

    function renameMember(name, newName) {
        // note: the members array is not updated in this case
        // to avoid a binding loop when editing members
        renamedMembers[name] = newName
    }

    onRowidChanged: {
        if (rowid == -1) {
            return
        } else if (rowid < -1) {
            name = ''
            baseCurrency = ''
            members = []
            expenses.clear()
        } else {
            reloadMetadata()
            reloadContents()

            console.log("loaded project data:", rowid, name, members)
            loaded(rowid)
        }
    }
}
