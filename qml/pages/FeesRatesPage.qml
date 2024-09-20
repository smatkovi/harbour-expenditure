import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0
import Opal.SmartScrollbar 1.0

import "../enums"
import "../components"
import "../js/storage.js" as Storage
import "../js/dates.js" as Dates

Dialog {
    id: root
    allowedOrientations: Orientation.All

    property int projectRowid
    readonly property bool dataHasChanged: _dataHasChanged

    property bool _dataHasChanged: false
    readonly property ProjectData _project: ProjectData {
        rowid: projectRowid
        loadExpenses: true
        loadRates: true
        sortOrder: SortOrder.increasing

        function setUpdated(rowid, key, value) {
            if (!updatedExpenses.hasOwnProperty(rowid)) {
                updatedExpenses[rowid] = {}
            }

            updatedExpenses[rowid][key] = value
        }

        property var updatedExpenses: ({})
    }

    onAccepted: {
        var updatedCount = 0

        for (var rowid in _project.updatedExpenses) {
            if (_project.updatedExpenses.hasOwnProperty(rowid)) {
                var values = _project.updatedExpenses[rowid]

                Storage.setExpenseRateAndFees(
                    _project.rowid, rowid, _project.updatedExpenses[rowid])
                ++updatedCount
            }
        }

        if (updatedCount) {
            console.log("updated", updatedCount, "entries")
            _dataHasChanged = true
        }
    }

    Component.onCompleted: {
        if (appWindow.maybeLoadDebugData()) {
            projectRowid = appWindow.activeProject.rowid
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent

        header: DialogHeader {
            title: qsTr("Transactions")
            acceptText: qsTr("Save")
            cancelText: qsTr("Discard")
        }

        SmartScrollbar {
            flickable: listView
            property date date: new Date(listView.currentSection)
            text: date.toLocaleString(Qt.locale(), Dates.dateNoYearFormat)
            description: date.toLocaleString(Qt.locale(), 'yyyy')
            smartWhen: listView.contentHeight > Screen.height
        }

        model: _project.expenses

        // cacheBuffer: 100 * Screen.height
        delegate: Component {
            EditableTransactionsListDelegate {
                project: _project

                onRateUpdated: _project.setUpdated(rowid, 'rate', value)
                onFixedFeesUpdated: _project.setUpdated(rowid, 'fixed_fees', value)
                onPercentageFeesUpdated: _project.setUpdated(rowid, 'percentage_fees', value)
            }
        }

        section {
            property: "section_string"
            delegate: SectionHeader {
                text: new Date(section).toLocaleString(Qt.locale(), Dates.fullDateFormat)
            }
        }

        footer: Spacer { size: Theme.horizontalPageMargin }
    }
}
