/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import QtQuick.Layouts 1.1
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import Opal.Delegates 1.0

import "../py"
import "../components"
import "../js/storage.js" as Storage
import "../js/calculation.js" as Calculation

Page {
    id: root
    allowedOrientations: Orientation.All

    property var expenses: ({})
    property string baseCurrency: ''
    property var payments: ({})
    property var benefits: ({})
    property var balances: ({})
    property real totalPayments: 0.00
    property var settlement: ([])
    property var people: ([])

    function calculate() {
        var results = Calculation.calculate(appWindow.activeProject)

        expenses = results.expenses
        baseCurrency = results.baseCurrency
        payments = results.payments
        benefits = results.benefits
        balances = results.balances
        totalPayments = results.totalPayments
        settlement = results.settlement
        people = results.people
    }

    function editTransactions() {
        var dialog = pageStack.push(Qt.resolvedUrl("FeesRatesPage.qml"),
                                    {projectRowid: appWindow.activeProject.rowid})
        dialog.accepted.connect(function(){
            if (dialog.dataHasChanged) {
                console.log("recalculating...")
                appWindow.activeProject.reloadContents()
                calculate()
            }
        })
    }

    function createReport(detailed) {
        py.importModule('import_export', function() {
            calculate()
            var project = appWindow.activeProject.rowid
            var entries = Storage.getProjectEntries(project)
            var metadata = Storage.getProjectMetadata(project)
            var rates = Storage.getProjectExchangeRates(project)

            var payments = root.payments
            var benefits = root.benefits
            var balances = root.balances
            var settlement = root.settlement
            var totalPayments = root.totalPayments

            py.call('import_export.doCreateReport',
                    [metadata, entries, rates,
                     payments, benefits, balances,
                     totalPayments, settlement,
                     detailed],
            function(report){
                var msg = detailed ?
                    qsTr("A detailed report has been copied to the clipboard.") :
                    qsTr("A compact report has been copied to the clipboard.")
                Notices.show(msg, 5000, Notice.Top)

                Clipboard.text = report
                shareAction.mimeType = "text/plain"  // actually Markdown...
                shareAction.resources = [{
                    "data": report,
                    "name": "%1 [%2].txt".arg(metadata.name)
                                         .arg(metadata.baseCurrency),
                }]
                shareAction.trigger()
            })
        })
    }

    PythonBackend {
        id: py
    }

    ShareAction {
        id: shareAction
        title: qsTr("Spendings report")
    }

    Component.onCompleted: {
        appWindow.maybeLoadDebugData()
        calculate()
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        VerticalScrollDecorator { flickable: flick }

        PullDownMenu {
            MenuItem {
                text: qsTr("Review transactions")
                onClicked: editTransactions()
            }
            MenuItem {
                text: qsTr("Share detailed report")
                onClicked: createReport(true)
            }
            MenuItem {
                text: qsTr("Share compact report")
                onClicked: createReport(false)
            }
        }

        Column {
            id: content
            width: parent.width
            height: childrenRect.height

            PageHeader {
                title: qsTr("Calculations")
                description: appWindow.activeProject.active ?
                                 "%1 [%2]".arg(appWindow.activeProject.name)
                                          .arg(appWindow.activeProject.baseCurrency) :
                                 " "
            }

            SectionHeader {
                text: qsTr("Spending overview")
            }

            GridLayout {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                columns: 4
                columnSpacing: Theme.paddingSmall
                rowSpacing: 0

                TotalsGridHeader {
                    text: qsTr("Name")
                    horizontalAlignment: Text.AlignLeft
                }
                TotalsGridHeader { text: qsTr("Payments") }
                TotalsGridHeader { text: qsTr("Benefits") }
                TotalsGridHeader { text: qsTr("Balance") }

                Repeater {
                    model: [].concat(people).concat([null, undefined])

                    Repeater {
                        id: innerRepeater
                        model: 4
                        property var person: modelData

                        CurrencyLabel {
                            property int i: index
                            text: {
                                if (innerRepeater.person === null) {
                                    " "
                                } else if (innerRepeater.person === undefined) {
                                    if (i == 0) qsTr("total")
                                    else if (i == 2) _valueText
                                    else if (i == 3) baseCurrency
                                    else " "
                                } else {
                                    i == 0 ? innerRepeater.person : _valueText
                                }
                            }
                            font.pixelSize: innerRepeater.person !== null ? Theme.fontSizeSmall : 20
                            horizontalAlignment: {
                                if (innerRepeater.person === undefined && i == 3) Text.AlignLeft
                                else i == 0 ? Text.AlignLeft : Text.AlignRight
                            }
                            color: {
                                if (innerRepeater.person === undefined && i == 3) Theme.primaryColor
                                else i == 0 ? Theme.highlightColor : _valueColor
                            }
                            leftPadding: i == 3 ? Theme.paddingMedium : 0
                            asBalance: i == 3
                            value: {
                                if (innerRepeater.person === null) 0
                                else if (innerRepeater.person === undefined) {
                                    if (i == 2) totalPayments
                                    else 0
                                } else {
                                    if (i == 0) 0
                                    else if (i == 1) payments[innerRepeater.person]
                                    else if (i == 2) benefits[innerRepeater.person]
                                    else if (i == 3) balances[innerRepeater.person]
                                }
                            }
                        }

                    }
                }
            }

            SectionHeader {
                text: qsTr("Settlement suggestion")
                visible: !!settlement && settlement.length > 0
            }

            GridLayout {
                visible: !!settlement && settlement.length > 0
                width: parent.width - 2*x
                x: Theme.horizontalPageMargin
                columnSpacing: Theme.paddingSmall
                rowSpacing: 0
                columns: 4

                TotalsGridHeader {
                    text: qsTr("Payer")
                    horizontalAlignment: Text.AlignLeft
                    Layout.fillWidth: true
                }
                TotalsGridHeader {
                    text: ''
                    Layout.fillWidth: false
                    Layout.preferredWidth: parent.width / 5
                }
                TotalsGridHeader {
                    text: qsTr("Recipient")
                    horizontalAlignment: Text.AlignLeft
                    Layout.fillWidth: true
                }
                TotalsGridHeader {
                    text: qsTr("Sum [%1]").arg(baseCurrency)
                    Layout.fillWidth: true
                }

                Repeater {
                    model: settlement

                    Repeater {
                        id: innerRepeater2
                        model: 4

                        property var set: [
                            modelData.from,
                            '→',
                            modelData.to,
                            Number(modelData.value).toLocaleString(Qt.locale('de_CH'))
                        ]

                        Label {
                            Layout.preferredWidth: parent.width / 7
                            Layout.maximumWidth: parent.width / 3
                            Layout.minimumWidth: 0
                            Layout.fillWidth: index !== 1

                            wrapMode: Text.Wrap
                            color: index == 3 ? Theme.primaryColor : Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            text: innerRepeater2.set[index]
                            horizontalAlignment: index == 3 ?
                                Text.AlignRight : Text.AlignLeft
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Base exchange rates")
            }

            EditableRatesList {
                id: exchangeRatesList
                selectedProject: ProjectData {
                    // cannot assign appWindow.activeProject, but why?
                    rowid: appWindow.activeProject.rowid
                    loadExpenses: false
                    loadRates: true
                }

                onExchangeRateChanged: {
                    Storage.setExchangeRate(selectedProject.rowid, currency, rate)
                    appWindow.activeProject.reloadRates()
                    calculate()
                }
            }

            SectionHeader {
                text: qsTr("Transactions and fees")
            }

            ButtonLayout {
                preferredWidth: Theme.buttonWidthLarge

                Button {
                    text: qsTr("Review transactions")
                    onClicked: editTransactions()
                }
            }

            InfoLabel {
                text: qsTr("Click here to review and edit fees and " +
                           "exchange rates individually for all transactions. " +
                           "Transactions that do not declare a custom " +
                           "exchange rate are converted using the base " +
                           "exchange rates defined above.")
                bottomPadding: Theme.paddingMedium
                topPadding: Theme.paddingLarge
            }
        }
    }
}
