import QtQuick 2.6
import Sailfish.Silica 1.0

import "../js/storage.js" as Storage

TextField {
    id: root

    property double value: emptyValue
    property double emptyValue: 0.00
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

    function _textToValue(text) {
        return Number(text.trim().replace(Qt.locale().decimalPoint, '.'))
    }

    function isAcceptable() {
        return !isEmpty() || allowEmpty
    }

    function isEmpty() {
        var value = _textToValue(text)

        if (!text.trim()) {
            return true
        } else if (value === 0.00) {
            return allowNull ? false : true
        } else if (isNaN(value) || Storage.isSameValue(value, emptyValue)) {
            return true
        } else {
            return false
        }
    }

    function apply(hadFocus) {
        // only convert text to value if it was unformatted,
        // i.e. if the field has or had focus
        if (activeFocus || hadFocus) {
            if (!acceptableInput) {
                console.log("not saving invalid input [2]:", text)
                _updateDisplayText()
                focus = false
            } else if (!!text) {
                value = _textToValue(text)
                _updateDisplayText()
                focus = false
            } else {
                value = emptyValue
            }
        }
    }

    function _updateDisplayText() {
        if (isNaN(value)) {
            text = ''
        } else if (precision == 2) {
            text = value.toLocaleCurrencyString(Qt.locale('de-CH'), ' ').trim()
        } else {
            text = value.toPrecision(precision)
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            // set unformatted text
            if (isNaN(value)) {
                text = ''
            } else if (value == 0.00) {
                text = '  %1  '.arg(value.toFixed(precision))
            } else {
                text = '  %1  '.arg(value.toString())
            }

            selectAll()
        } else {
            // save unformatted text as value
            // and format it to legibility
            apply(true)
        }
    }

    onTextChanged: {
        if (!focus) return
        if (!isAcceptable()) {
            console.log("not saving invalid input:", text)
            return
        }
        value = _textToValue(text)
    }

    onValueChanged: {
        console.log("VALUE CHANGED:", value, "'%1'".arg(text), emptyValue)

        if (focus) return // only update when not editing

        // set formatted text
        if (isNaN(value) && isNaN(emptyValue)) {
            text = ''
        } else {
            _updateDisplayText()
        }
    }

    Component.onCompleted: {
        // workaround for 0.00 (default value) not being
        // displayed because it doesn't initially trigger
        // valueChanged()
        if (value === 0.00 && !focus) text = '0.00'
    }
}
