/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

import "../js/storage.js" as Storage

DelegateColumn {
    id: membersList
    property ProjectData selectedProject

    model: selectedProject.members
    width: parent.width

    delegate: EditableMembersListDelegate {
        id: delegate
        text: selectedProject.renamedMembers[modelData] || modelData
        acceptableInput: !!text.trim() && text.indexOf(Storage.fieldSeparator) < 0
        onTextChanged: {
            if (text.trim()) {
                selectedProject.renameMember(modelData, text.trim())
            }
        }

        onEnterKeyClicked: textField.focus = false
        enterKeyIcon: "image://theme/icon-m-enter-close"

        actionEnabled: true
        actionIcon: "image://theme/icon-splus-remove"
        onActionTriggered: {
            var item = modelData
            var project = selectedProject
            delegate.remorseDelete(function(){
                project.removeMember(item)
            })
        }
    }
}
