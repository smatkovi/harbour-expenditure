import QtQuick 2.6
import Opal.Delegates 1.0

DelegateColumn {
    id: root
    property ProjectData selectedProject
    signal exchangeRateChanged(var rate, var currency)

    onExchangeRateChanged: {
        selectedProject.exchangeRates[currency] = rate
    }

    model: selectedProject.currencies
    width: parent.width

    delegate: EditableRatesListDelegate {
        id: delegate
        project: selectedProject
        currency: modelData
        onValueChanged: {
            root.exchangeRateChanged(value, currency)
        }
    }
}
