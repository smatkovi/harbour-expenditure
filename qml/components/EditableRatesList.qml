import QtQuick 2.6
import Opal.Delegates 1.0

DelegateColumn {
    id: root
    property ProjectData selectedProject
    signal exchangeRateChanged(var rate, var currency)

    function applyAll() {
        for (var i in root.children) {
            var child = root.children[i]

            if (child.hasOwnProperty('__isRatesListDelegate')) {
                child.apply(child.focus)
            }
        }
    }

    onExchangeRateChanged: {
        selectedProject.exchangeRates[currency] = rate
    }

    model: selectedProject.currencies
    width: parent.width

    delegate: EditableRatesListDelegate {
        id: delegate
        project: selectedProject
        currency: modelData
        value: fallback
        onValueChanged: {
            root.exchangeRateChanged(value, currency)
        }
    }
}
