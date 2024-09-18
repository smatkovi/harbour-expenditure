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

    function apply() {
        if (!!text) {
            value = Number(text.trim().replace(',', '.'))

            if (precision == 2) {
                text = value.toLocaleCurrencyString(Qt.locale('de-CH'), ' ').trim()
            } else {
                text = value.toFixed(precision)
            }
        } else {
            value = emptyValue
        }
    }

    onFocusChanged: {
        if (focus) {
            if (isNaN(value) && isNaN(emptyValue)) {
                text = ''
            } else if (value == 0.00) {
                text = '  %1  '.arg(value.toFixed(precision))
            } else {
                text = '  %1  '.arg(String(value))
            }

            selectAll()
        } else {
            apply()
        }
    }

    onValueChanged: {
        if (isNaN(value) && isNaN(emptyValue)) {
            text = ''
        } else {
            text = value.toLocaleCurrencyString(Qt.locale('de-CH'), ' ').trim()
        }
    }
}
