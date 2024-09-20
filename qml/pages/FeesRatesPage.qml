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
    readonly property ProjectData _project: ProjectData {
        rowid: projectRowid
        loadExpenses: true
        loadRates: true
        sortOrder: SortOrder.increasing

        function setUpdated(rowid, key, value) {
            if (!updatedExpenses.hasOwnProperty(rowid)) {
                updatedExpenses[rowid] = {}
            }

            console.log("UPDATED:", rowid, key, value)
            updatedExpenses[rowid][key] = value
        }

        property var updatedExpenses: ({})
    }

    onAccepted: {
//        var newRowids = Storage.saveProjects(allProjects)
//        Storage.setActiveProjectId(newRowids[projectCombo.currentIndex])
//        appWindow.activeProject.rowid = newRowids[projectCombo.currentIndex]
//        appWindow.activeProject.reloadMetadata()
//        appWindow.activeProject.reloadRates()
//        appWindow.activeProject.reloadContents() // in case members have changed
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
