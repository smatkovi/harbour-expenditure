import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

import "../js/storage.js" as Storage  // for isSameValue()

PaddedDelegate {
    id: root
    property ProjectData project
    property string currency
    property alias allowEmpty: _inputField.allowEmpty
    property alias emptyValue: _inputField.emptyValue
    property double foreignSum: NaN
    property string placeholder: ''

    property alias inputField: _inputField

    // effective value is: X base currency = 1.00 foreign currency (B2F)
    property double fallback: project.exchangeRates[currency] || NaN
    property double value: emptyValue

    property string _displayType: 'B2F'
    property string _displayDescription: "%1 = 1.00 %2".
        arg(project.baseCurrency).arg(currency)

    minContentHeight: Theme.itemSizeSmall
    centeredContainer: contentContainer
    interactive: true
    padding.topBottom: 0
    contentItem.color: "transparent"
    onClicked: openMenu()
    enabled: currency !== project.baseCurrency

    menu: ContextMenu {
        MenuItem {
            text: "%1 = 1.00 %2".arg(project.baseCurrency)
                                .arg(currency)
            onClicked: {
                root._displayType = 'B2F'
                _inputField.value = value
                root._displayDescription = Qt.binding(function(){return text})
            }
        }
        MenuItem {
            text: "%1 = 1.00 %2".arg(currency)
                                .arg(project.baseCurrency)
            onClicked: {
                root._displayType = 'F2B'
                _inputField.value = value > 0 ? 1/value : emptyValue
                root._displayDescription = Qt.binding(function(){return text})
            }
        }
        MenuItem {
            visible: !Storage.isSameValue(foreignSum, NaN)
            text: qsTr("%1 paid").arg(project.baseCurrency)
            onClicked: {
                root._displayType = 'paid'
                _inputField.value = value > 0 ? foreignSum*value : emptyValue
                root._displayDescription = Qt.binding(function(){return text})
            }
        }
    }

    Rectangle {
        id: highlightItem
        z: -1000
        anchors.right: parent.right
        parent: root.contentItem
        height: parent.height
        width: parent.width / 2
        color: root._showPress ? root.highlightedColor : "transparent"
    }

    Column {
        id: contentContainer
        width: root.width - 2*Theme.horizontalPageMargin

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            CurrencyInputField {
                id: _inputField
                readOnly: !root.enabled
                width: parent.width / 2 - parent.spacing
                label: qsTr("Exchange rate")
                labelVisible: false
                emptyValue: NaN
                allowEmpty: false
                allowNull: false
                precision: 4
                value: root.value || root.emptyValue
                textRightMargin: 0
                textMargin: 0
                textTopPadding: Theme.paddingMedium

                Component.onCompleted: value = root.value || root.emptyValue

                placeholderText: {
                    if (Storage.isSameValue(root.placeholder, NaN) ||
                            !(root.placeholder > 0)) {
                        ''
                    } else if (_displayType === 'B2F') {
                        Number(root.placeholder).toPrecision(precision)
                    } else if (_displayType === 'F2B') {
                        Number(1/root.placeholder).toPrecision(precision)
                    } else if (_displayType === 'paid') {
                        Number(foreignSum*root.placeholder).toPrecision(precision)
                    }
                }

                onValueChanged: {
                    var newValue = emptyValue

                    if (_displayType === 'B2F') {
                        newValue = _inputField.value
                    } else if (_displayType === 'F2B') {
                        newValue = value > 0 ? 1/_inputField.value : emptyValue
                    } else if (_displayType === 'paid') {
                        newValue = value > 0 ? _inputField.value/foreignSum : emptyValue
                    }

                    if (!Storage.isSameValue(newValue, root.value)) {
                        root.value = newValue // avoid a binding loop
                    }
                }
            }

            Label {
                width: parent.width / 2
                height: parent.height
                leftPadding: parent.spacing
                rightPadding: Theme.horizontalPageMargin
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                truncationMode: TruncationMode.Fade
                text: _displayDescription
            }
        }
    }
}
