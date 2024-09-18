import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0

import "../js/storage.js" as Storage  // for isSameValue()

PaddedDelegate {
    id: root
    property ProjectData project
    property string currency
    property bool allowEmpty: false
    property double emptyValue: NaN
    property double foreignSum: NaN
    property string placeholder: ''

    // effective value is: X base currency = 1.00 foreign currency (B2F)
    property double fallback: project.exchangeRates[currency] || NaN
    property double value: fallback

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

    onFocusChanged: {
        if (focus) {
            inputField.forceActiveFocus()
        }
    }

    function apply(hadFocus) {
        inputField.apply(hadFocus)
    }

    menu: ContextMenu {
        MenuItem {
            text: "%1 = 1.00 %2".arg(project.baseCurrency)
                                .arg(currency)
            onClicked: {
                root._displayType = 'B2F'
                inputField.value = value
                root._displayDescription = text
            }
        }
        MenuItem {
            text: "%1 = 1.00 %2".arg(currency)
                                .arg(project.baseCurrency)
            onClicked: {
                root._displayType = 'F2B'
                inputField.value = value > 0 ? 1/value : emptyValue
                root._displayDescription = text
            }
        }
        MenuItem {
            visible: !Storage.isSameValue(foreignSum, NaN)
            text: qsTr("%1 paid").arg(project.baseCurrency)
            onClicked: {
                root._displayType = 'paid'
                inputField.value = value > 0 ? foreignSum*value : emptyValue
                root._displayDescription = text
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
                id: inputField
                readOnly: !root.enabled
                width: parent.width / 2 - parent.spacing
                label: qsTr("Exchange rate")
                acceptableInput: allowEmpty ? true : !!text.trim()
                labelVisible: false
                emptyValue: root.emptyValue
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
                        newValue = inputField.value
                    } else if (_displayType === 'F2B') {
                        newValue = value > 0 ? 1/inputField.value : emptyValue
                    } else if (_displayType === 'paid') {
                        newValue = value > 0 ? inputField.value/foreignSum : emptyValue
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
