import QtQuick 2.6
import Sailfish.Silica 1.0

TextField {
    id: root
    property double value: emptyValue
    property double emptyValue: 0.00
    property int precision: 2

    inputMethodHints: Qt.ImhFormattedNumbersOnly
    EnterKey.onClicked: focus = false
    EnterKey.iconSource: "image://theme/icon-m-enter-close"

    function apply(hadFocus) {
        // only convert text to value if it was unformatted,
        // i.e. if the field has or had focus
        if (activeFocus || hadFocus) {
            if (!acceptableInput) {
                console.log("not saving invalid input:", text)
                _updateDisplayText()
                focus = false
            } else if (!!text) {
                value = Number(text.trim().replace(Qt.locale().decimalPoint, '.'))
                _updateDisplayText()
                focus = false
            } else {
                value = emptyValue
            }
        }
    }

    function _updateDisplayText() {
        if (precision == 2) {
            text = value.toLocaleCurrencyString(Qt.locale('de-CH'), ' ').trim()
        } else {
            text = value.toPrecision(precision)
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            // set unformatted text
            if (isNaN(value) && isNaN(emptyValue)) {
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

    onValueChanged: {
        // set formatted text
        if (isNaN(value) && isNaN(emptyValue)) {
            text = ''
        } else {
            _updateDisplayText()
        }
    }
}
