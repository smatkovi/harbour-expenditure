/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0

import "../js/math.js" as M

TextField {
    id: root

    property string value: emptyValue
    property string emptyValue: '0.00'
    property int precision: 2
    property bool allowEmpty: false
    property bool allowNull: true

    inputMethodHints: Qt.ImhFormattedNumbersOnly
    EnterKey.onClicked: focus = false
    EnterKey.iconSource: "image://theme/icon-m-enter-close"

    acceptableInput: isAcceptable()

    Binding on acceptableInput {
        when: root.focus
        value: isAcceptable()
    }

    function _getCleanText() {
        return M.cleanNumberString(text)
    }

    function _textToValue() {
        return M.value(M.expand(_getCleanText() || emptyValue))
    }

    function isAcceptable() {
        return !isEmpty() || allowEmpty
    }

    function isEmpty() {
        if (   _getCleanText() === ''
            || _getCleanText() === emptyValue) {
            return true
        }

        var value = _textToValue()

        if (value.isZero()) {
            return allowNull ? false : true
        } else if (value.eq(emptyValue) ||
                   (value.isNaN() && M.isNotNum(emptyValue))) {
            return true
        } else {
            return false
        }
    }

    function _updateDisplayText() {
        if (M.isNotNum(value)) {
            text = ''
        } else {
            text = M.format(value, precision)
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            // set unformatted text
            if (M.isNotNum(value)) {
                text = ''
            } else {
                text = '  %1  '.arg(M.string(value, precision))
            }

            selectAll()
        } else {
            // save unformatted text as value
            // and format it for legibility
            if (!acceptableInput) {
                console.log("not saving invalid input [2]:", text)
                _updateDisplayText()
                focus = false
            } else if (!!text) {
                value = _textToValue().toString()
                _updateDisplayText()
                focus = false
            } else {
                value = emptyValue
            }
        }
    }

    onTextChanged: {
        if (!focus) return
        if (!isAcceptable()) {
            console.log("not saving invalid input:", text)
            return
        }

        value = _textToValue().toString()
    }

    onValueChanged: {
        if (focus) return // only update when not editing

        // set formatted text
        if (M.isNotNum(value) && M.isNotNum(emptyValue)) {
            text = ''
        } else {
            _updateDisplayText()
        }
    }
}
