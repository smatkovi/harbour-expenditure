/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

import io.thp.pyotherside 1.5
import Opal.ComboData 1.0
import Opal.Delegates 1.0 as D

import "../components"
import "../js/storage.js" as Storage

Dialog {
    id: root
    allowedOrientations: Orientation.All

    property var allProjects: Storage.getProjects(projectDataComponent, root)
    property ProjectData selectedProject: ProjectData { rowid: -1000 }
    property string _newProjectName: qsTr("New project")

    Component {
        id: projectDataComponent
        ProjectData { loadExpenses: false }
    }

    function deleteCurrentProject() {
        if (projectCombo.currentIndex >= 0 &&
                projectCombo.currentIndex < allProjects.length) {
            allProjects.splice(projectCombo.currentIndex, 1)
            allProjects = allProjects
            projectCombo.currentIndex = -1
            projectCombo.currentIndex = 0
        }
    }

    function exportCurrentProject() {
        if (selectedProject.rowid < 0) return

        var dialog = pageStack.push('Sailfish.Pickers.FolderPickerDialog', {
            'path': StandardPaths.documents,
            'title': qsTr("Export to", "Page title for the backup output folder picker")
        })
        dialog.accepted.connect(function(){
            py.importModule('import_export', function() {
                var entries = Storage.getProjectEntries(selectedProject.rowid)
                py.call('import_export.doExport',
                        [entries, dialog.selectedPath,
                        selectedProject.name, selectedProject.baseCurrency],
                function(outputPath){
                    Notices.show(qsTr("Exported expenses to “%1”").arg(
                        outputPath), 5000, Notice.Center)
                })
            })
        })
    }

    function importCurrentProject() {
        var picker = pageStack.push('Sailfish.Pickers.FilePickerPage', {
            'title': qsTr("Import expenses", "Page title for the file import picker"),
            'nameFilters': ['*.csv']
        })
        picker.selectedContentPropertiesChanged.connect(function(){
            if (!picker.selectedContentProperties) return
            var filePath = picker.selectedContentProperties.filePath

            py.importModule('import_export', function() {
                py.call('import_export.doImport', [filePath],
                function(expenses){
                    if (!!expenses) {
                        selectedProject.importedExpenses = expenses
                        Notices.show(qsTr("Imported %1 expenses into “%2”.").arg(
                            expenses.length).arg(selectedProject.name),
                            5000, Notice.Center)
                    } else {
                        Notices.show(qsTr("Failed to import “%1”.",
                            "%1 is a filename").arg(filePath), Notice.Center)
                    }
                })
            })
        })
    }

    Python {
        id: py
        Component.onCompleted: addImportPath(Qt.resolvedUrl('../py'))
        onReceived: { Notices.show(data); console.log(data) }
        onError: {
            console.error("an error occurred in the Python backend, traceback:")
            console.error(traceback)

            Notices.show("\n" + qsTr("An error occurred in the Python backend.\n" +
                                     "Please restart the app and check the logs.") +
                         "\n", 10000, Notice.Center)
        }
    }

    onAccepted: {
        var newRowids = Storage.saveProjects(allProjects)
        Storage.setSetting('activeProjectID_unixtime', newRowids[projectCombo.currentIndex])
        appWindow.activeProject.rowid = newRowids[projectCombo.currentIndex]
        appWindow.activeProject.reloadMetadata()
        appWindow.activeProject.reloadContents() // in case members have changed
    }

    Component.onCompleted: {
        if (allProjects.length === 0) {
            // if there are no projects, immediately set up a new one
            projectCombo.currentIndex = -1
            projectCombo.currentIndex = 0
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        VerticalScrollDecorator { flickable: flick }

        Column {
            id: content
            width: parent.width
            height: childrenRect.height

            DialogHeader {
                title: qsTr("Settings")
            }

            ListItem {
                id: projectsContainer
                contentHeight: projectCombo.height

                ComboBox {
                    id: projectCombo
                    label: qsTr("Project")
                    rightMargin: Theme.horizontalPageMargin + Theme.iconSizeMedium
                    currentIndex: -1

                    onCurrentIndexChanged: {
                        if (currentIndex < 0) return

                        if (currentIndex >= allProjects.length) {
                            var newProjectData = {
                                rowid: -1,
                                name: _newProjectName,
                                baseCurrency: Qt.locale().currencySymbol(Locale.CurrencyIsoCode)
                            }

                            allProjects.push(projectDataComponent.createObject(root, newProjectData))
                        }

                        selectedProject = allProjects[currentIndex]

                        if (!!newProjectData) {
                            allProjects = allProjects
                        }
                    }

                    menu: ContextMenu {
                        Repeater {
                            model: allProjects.concat([{rowid: -1000}])

                            MenuItem {
                                property double value: modelData.rowid
                                text: value == -1000 ?
                                          qsTr("New project ...") :
                                          "%1 [%2]".arg(modelData.name).arg(modelData.baseCurrency)

                                Component.onCompleted: {
                                    var check = selectedProject.rowid
                                    if (check < -1) {
                                        check = appWindow.activeProject.rowid
                                    }

                                    if (value == check) {
                                        projectCombo.currentIndex = index
                                    }
                                }
                            }
                        }
                    }

                    IconButton {
                        enabled: projectCombo.enabled && projectCombo.currentIndex >= 0
                        anchors.right: parent.right
                        icon.source: "image://theme/icon-m-delete"

                        onClicked: {
                            projectsContainer.remorseDelete(function(){
                                root.deleteCurrentProject()
                            })
                        }

                        Binding on highlighted {
                            when: projectCombo.highlighted
                            value: true
                        }
                    }
                }
            }

            ComboBox {
                id: ratesModeCombo
                width: parent.width
                label: qsTr("Exchange rate")

                property var indexOfData
                property int currentData
                ComboData { dataRole: 'value' }

                menu: ContextMenu {
                    MenuItem {
                        property int value: 0
                        text: qsTr("fixed per currency")
                    }
                    MenuItem {
                        property int value: 1
                        text: qsTr("per transaction date")
                    }
                }

                onCurrentDataChanged: {
                    if (currentData != selectedProject.ratesMode) {
                        selectedProject.ratesMode = currentData
                    }
                }

                Component.onCompleted: {
                    currentIndex = indexOfData(selectedProject.ratesMode)
                }

                Connections {
                    target: root
                    onSelectedProjectChanged: {
                        ratesModeCombo.currentIndex = ratesModeCombo.indexOfData(
                            selectedProject.ratesMode)
                    }
                }
            }

            Item { width: parent.width; height: Theme.paddingLarge }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                TextField {
                    id: nameField
                    text: selectedProject.name
                    width: parent.width / 5 * 3 - parent.spacing
                    label: qsTr("Name")
                    textRightMargin: 0
                    acceptableInput: !!text
                    EnterKey.onClicked: focus = false
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    onFocusChanged: {
                        if (focus && text === _newProjectName) {
                            selectAll()
                        }
                    }

                    onTextChanged: {
                        if (text) {
                            selectedProject.name = text
                        }
                    }
                }

                TextField {
                    id: currencyField
                    text: selectedProject.baseCurrency
                    width: parent.width / 5 * 2
                    acceptableInput: !!text && text.length < 100
                    label: qsTr("Currency")
                    onFocusChanged: if (focus) selectAll()
                    EnterKey.onClicked: focus = false
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    inputMethodHints: Qt.ImhNoPredictiveText
                    onTextChanged: {
                        if (text) {
                            selectedProject.baseCurrency = text
                        }
                    }
                }
            }

            Label {
                text: qsTr("The settlement suggestion is calculated in this " +
                           "currency. Select the most used currency in your " +
                           "group for this.")
                width: parent.width - 2*x
                x: Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                bottomPadding: Theme.paddingMedium
            }

            SectionHeader {
                text: qsTr("Project members")
            }

            D.DelegateColumn {
                id: membersList
                model: selectedProject.members
                width: parent.width

                delegate: D.PaddedDelegate {
                    id: delegate
                    minContentHeight:Theme.itemSizeSmall
                    centeredContainer: contentContainer
                    interactive: false
                    padding.topBottom: 0

                    Column {
                        id: contentContainer
                        width: parent.width

                        TextField {
                            width: parent.width
                            acceptableInput: !!text.trim() && text.indexOf(Storage.fieldSeparator) < 0
                            text: selectedProject.renamedMembers[modelData] || modelData
                            textMargin: 0
                            textTopPadding: 0
                            labelVisible: false
                            EnterKey.onClicked: focus = false
                            EnterKey.iconSource: "image://theme/icon-m-enter-close"

                            onTextChanged: {
                                if (text.trim()) {
                                    selectedProject.renameMember(modelData, text.trim())
                                }
                            }
                        }
                    }

                    rightItem: IconButton {
                        width: Theme.iconSizeSmallPlus
                        icon.source: "image://theme/icon-splus-remove"
                        onClicked: {
                            var item = modelData
                            var project = selectedProject
                            delegate.remorseDelete(function(){
                                project.removeMember(item)
                            })
                        }
                    }
                }
            }

            D.PaddedDelegate {
                id: addMemberItem
                minContentHeight:Theme.itemSizeSmall
                centeredContainer: contentContainer2
                interactive: false
                padding.topBottom: 0

                property int index: 0
                property bool canApply: !!newMemberField.text.trim()

                function apply() {
                    if (canApply) {
                        selectedProject.addMember(newMemberField.text.trim())
                        flick.scrollToBottom()
                        newMemberField.text = ''
                        newMemberField.forceActiveFocus()
                    }
                }

                Column {
                    id: contentContainer2
                    width: parent.width

                    TextField {
                        id: newMemberField
                        width: parent.width
                        textMargin: 0
                        textTopPadding: 0
                        labelVisible: false
                        EnterKey.onClicked: {
                            if (addMemberItem.canApply) addMemberItem.apply()
                            else focus = false
                        }
                        EnterKey.iconSource: addMemberItem.canApply ?
                            "image://theme/icon-m-add" :
                            "image://theme/icon-m-enter-close"
                        onFocusChanged: {
                            if (!focus && addMemberItem.canApply) {
                                addMemberItem.apply()
                            }
                        }
                    }
                }

                rightItem: IconButton {
                    enabled: !!newMemberField.text
                    width: Theme.iconSizeSmallPlus
                    icon.source: "image://theme/icon-splus-add"
                    onClicked: addMemberItem.apply()
                }
            }

            SectionHeader {
                text: qsTr("Backup options")
                topPadding: 2 * Theme.paddingLarge
                bottomPadding: 2 * Theme.paddingLarge
            }

            ButtonLayout {
                Button {
                    text: qsTr("Import")
                    onClicked: importCurrentProject()
                }
                Button {
                    text: qsTr("Export")
                    onClicked: exportCurrentProject()
                }
            }

            Label {
                text: qsTr("You can import and export expenses of the current " +
                           "project to CSV. Project metadata is not included.") + " " +
                      qsTr("When importing, imported entries will be added to " +
                           "the current project and old entries will be kept.")
                width: parent.width - 2*x
                x: Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                topPadding: Theme.paddingLarge
                bottomPadding: Theme.paddingMedium
            }
        }
    }
}
