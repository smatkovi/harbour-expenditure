/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

EditableMembersListDelegate {
    id: addMemberItem
    property ProjectData selectedProject
    signal applied

    _isOddRow: false
    readonly property bool canApply: !!text.trim()

    placeholderText: qsTr("New member name")

    onTextFieldFocusChanged: {
        if (!focus && canApply) {
            apply()
        }
    }
    onEnterKeyClicked: {
        if (canApply) apply()
        else textField.focus = false
    }
    enterKeyIcon: canApply ?
                      "image://theme/icon-m-add" :
                      "image://theme/icon-m-enter-close"

    actionEnabled: !!text
    actionIcon: "image://theme/icon-splus-add"
    onActionTriggered: apply()

    function apply() {
        if (canApply) {
            selectedProject.addMember(text.trim())
            text = ''
            textField.forceActiveFocus()
            applied()
        }
    }
}
