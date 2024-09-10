/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import FileIO 1.0
import Nemo.Notifications 1.0

import Opal.ComboData 1.0
import Opal.InfoCombo 1.0
import Opal.Delegates 1.0 as D

import "../components"
import "../js/storage.js" as Storage

Dialog {
    id: root
    allowedOrientations: Orientation.All

    property var allProjects: Storage.getProjects(projectDataComponent, root)
    property ProjectData selectedProject: ProjectData { project_id_timestamp: -1000 }

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
        Notices.show('Not implemented yet')
    }

    function importCurrentProject() {
        Notices.show('Not implemented yet')
    }

    onAccepted: {
        Notices.show('Not implemented yet')
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
                                project_id_timestamp: -1,
                                name: qsTr("New project"),
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
                            model: allProjects.concat([{project_id_timestamp: -1000}])

                            MenuItem {
                                property double value: modelData.project_id_timestamp
                                text: value == -1000 ?
                                          qsTr("New project ...") :
                                          "%1 [%2]".arg(modelData.name).arg(modelData.baseCurrency)

                                Component.onCompleted: {
                                    var check = selectedProject.project_id_timestamp
                                    if (check < -1) {
                                        check = appWindow.activeProject.project_id_timestamp
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
                // TODO configure exchange rate preference per project
                width: parent.width
                label: qsTr("Exchange rate")

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("per currency (constant)")
                    }
                    MenuItem {
                        text: qsTr("per transaction (dates)")
                    }
                }
            }

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

                            onTextChanged: {
                                if (text) {
                                    selectedProject.renameMember(modelData, text.trim())
                                }
                            }
                        }
                    }

                    rightItem: IconButton {
                        width: Theme.iconSizeSmallPlus
                        icon.source: "image://theme/icon-splus-remove"
                        onClicked: {
                            // delegate.animateRemoval()
                            selectedProject.removeMember(modelData)
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

                function apply() {
                    if (!!newMemberField.text) {
                        selectedProject.addMember(newMemberField.text)
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
                        EnterKey.onClicked: addMemberItem.apply()
                        onFocusChanged: {
                            if (!focus && !!text) {
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
                text: qsTr("You can import and export expenses and metadata " +
                           "of the current project to CSV.")
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

    // ********************


//    property string notificationString : ""

//    onOpened: {
//        //console.log("old project index = " + activeProjectID_unixtime)
////        updateEvenWhenCanceled = false
////        idComboboxProject.currentIndex = 0
////        for (var j = 0; j < listModel_allProjects.count ; j++) {
////            if (Number(listModel_allProjects.get(j).project_id_timestamp) === Number(Storage.getSetting("activeProjectID_unixtime", 0))) {
////                idComboboxProject.currentIndex = j
////            }
////        }
////        idComboboxSortingExpenses.currentIndex = Number(Storage.getSetting("sortOrderExpensesIndex", 0)) // 0=descending, 1=ascending
////        idComboboxExchangeRateMode.currentIndex = Number(Storage.getSetting("exchangeRateModeIndex", 0)) // 0=collective, 1=individual
////        notificationString = ""
//    }

//    onDone: {
//        if (result == DialogResult.Accepted) {
//            writeDB_Settings()
//        }
//    }

//    onRejected: {
//        // in certain cases reload list even on cancel: if project was cleared, delted or created
//        // then use previous activeProjectID_unixtime instead of the new one from dropdown menu
//        if (updateEvenWhenCanceled === true) {
//            loadActiveProjectInfos_FromDB(activeProjectID_unixtime)
//            updateEvenWhenCanceled = false
//        }
//    }

////    BannerAddProject {
////        id: bannerAddProject
////    }
//    Banner2ButtonsChoice {
//        id: banner2ButtonsChoice
//    }
//    Notification {
//        id: notificationBackup
//        expireTimeout: 4000
//        //appName: qsTr("Expenditure")
//        //icon: "image://theme/icon-lock-warning"

//        function showSmall(message) {
//            replacesId = 0
//            previewSummary = ""
//            previewBody = message
//            publish()
//        }
//        function showBig(title, message) {
//            replacesId = 0
//            previewSummary = title
//            previewBody = message
//            publish()
//        }
//    }

//    Component {
//        id: idFolderPickerPage

//        FolderPickerPage {
//            dialogTitle: qsTr("Backup to")
//            onSelectedPathChanged: {
//                backupProjectExpenses( selectedPath )
//            }
//        }
//    }
//    Component {
//       id: idFilePickerPage

//       FilePickerPage {
//           title: qsTr("Restore backup file")
//           nameFilters: [ '*.csv' ]
//           onSelectedContentPropertiesChanged: {
//               var selectedPath = selectedContentProperties.filePath
//               idTextFileBackup.source = selectedPath
//               var tempProjectIndex_File = ((idTextFileBackup.text).split("\n"))[0]
//               var tempProjectIndex = listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp
//               var headlineText = qsTr("Restore backup - choose action")
//               var otherText = qsTr("Replace deletes all former project-expenses and uses those from backup-file instead.") + " "
//                            + qsTr("Merge keeps former project-expenses and adds those from backup-file which are not yet on the list.")
//               if (parseInt(tempProjectIndex) !== parseInt(tempProjectIndex_File)) {
//                   var detailText = qsTr("File info: This backup was created by a different project.")
//               } else {
//                   detailText = qsTr("File info: This backup was created by the original project.")
//               }
//               var choiceText_1 = qsTr("Replace")
//               var choiceText_2 = qsTr("Merge")
//               banner2ButtonsChoice.notify( Theme.rgba(Theme.highlightDimmerColor, 1), Theme.itemSizeLarge, headlineText, detailText, otherText, choiceText_1, choiceText_2, selectedPath )
//           }
//       }
//    }

//    TextFileIO {
//        id: idTextFileBackup
//    }

////    SilicaFlickable{
////        anchors.fill: parent
////        contentHeight: column.height // tell overall height

////        Column {
////            id: column
////            width: root.width

////            DialogHeader {
////                title: qsTr("Settings")
////            }

////            Row {
////                width: parent.width

////                ComboBox {
////                    id: idComboboxProject
////                    width: (listModel_allProjects.count === 0) ? (parent.width / 6*5) : (parent.width / 6*4)
////                    label: qsTr("Project")
////                    menu: ContextMenu {

////                        Repeater {
////                            enabled: listModel_allProjects.count > 0
////                            model: listModel_allProjects

////                            MenuItem {
////                                text: project_name
////                            }
////                        }
////                    }

////                    MouseArea {
////                        enabled: listModel_allProjects.count === 0
////                        anchors.fill: parent
////                        preventStealing: true
////                        onClicked: bannerAddProject.notify( Theme.rgba(Theme.highlightDimmerColor, 1), Theme.itemSizeLarge, "new", idComboboxProject.currentIndex )
////                    }
////                }
////                IconButton {
////                    visible: listModel_allProjects.count > 0
////                    width: parent.width / 6
////                    icon.source:  "image://theme/icon-m-edit?"
////                    onClicked: {
////                        bannerAddProject.notify( Theme.rgba(Theme.highlightDimmerColor, 1), Theme.itemSizeLarge, "edit", idComboboxProject.currentIndex )
////                    }
////                }
////                IconButton {
////                    width: parent.width / 6
////                    icon.source:  "image://theme/icon-m-add?"
////                    onClicked: {
////                        bannerAddProject.notify( Theme.rgba(Theme.highlightDimmerColor, 1), Theme.itemSizeLarge, "new", idComboboxProject.currentIndex )
////                    }
////                }
////            }
////            ComboBox {
////                id: idComboboxSortingExpenses
////                width: parent.width
////                label: qsTr("Sorting")

////                menu: ContextMenu {
////                    MenuItem {
////                        text: qsTr("descending")
////                    }
////                    MenuItem {
////                        text: qsTr("ascending")
////                    }
////                }
////            }
////            ComboBox {
////                id: idComboboxExchangeRateMode
////                width: parent.width
////                label: qsTr("Exchange rate")
////                menu: ContextMenu {
////                    MenuItem {
////                        text: qsTr("per currency (constant)")
////                    }
////                    MenuItem {
////                        text: qsTr("per transaction (dates)")
////                    }
////                }
////            }

////            Item {
////                width: parent.width
////                height: Theme.paddingLarge
////            }
////        }
////    }



//    // ******************************************** important functions ******************************************** //

//    function writeDB_Settings() {
//        Storage.setSetting("sortOrderExpensesIndex", idComboboxSortingExpenses.currentIndex)
//        sortOrderExpenses = idComboboxSortingExpenses.currentIndex
//        listModel_activeProjectExpenses.quick_sort()

//        Storage.setSetting("exchangeRateModeIndex", idComboboxExchangeRateMode.currentIndex)
//        exchangeRateMode = idComboboxExchangeRateMode.currentIndex

//        if (listModel_allProjects.count > 0) { // only works if a project is actually created and loaded, otherwise this gets triggered directly in BannerAddProject.qml
//            Storage.setSetting("activeProjectID_unixtime", Number(listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp))
//            activeProjectID_unixtime = Number(listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp)
//            loadActiveProjectInfos_FromDB(Number(listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp))
//        }

//        // ToDo: update base currency, if it was changed
//    }

//    function backupProjectExpenses(selectedPath) {
//        listModel_tempProjectExpenses.clear()
//        var tempProjectIndex = listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp
//        var backupFileName = encodeURIComponent(listModel_allProjects.get(idComboboxProject.currentIndex).project_name) + "_backup.csv" //replaces misleading special characters with %-symbols
//        var backupFilePath = selectedPath + "/" + backupFileName //StandardPaths.documents

//        // check if project exists
//        var currentProjectEntries = Storage.getAllExpenses(listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp, "none")
//        if (currentProjectEntries !== "none") {
//            // generate temp project expenses list from chosen list
//            for (var i = 0; i < currentProjectEntries.length ; i++) {
//                listModel_tempProjectExpenses.append({
//                    id_unixtime_created : Number(currentProjectEntries[i][0]).toFixed(0),
//                    date_time : Number(currentProjectEntries[i][1]).toFixed(0),
//                    expense_name : currentProjectEntries[i][2],
//                    expense_sum : Number(currentProjectEntries[i][3]).toFixed(2),
//                    expense_currency : currentProjectEntries[i][4],
//                    expense_info : currentProjectEntries[i][5],
//                    expense_payer : currentProjectEntries[i][6],
//                    expense_members : currentProjectEntries[i][7],
//                })
//            }
//            // create string from these temp info
//            var toBackupString = tempProjectIndex + "\n"
//                        + listModel_allProjects.get(idComboboxProject.currentIndex).project_name + "\n"
//                        + "id_unixtime_created;*;date_time;*;expense_payer;*;expense_name;*;expense_sum;*;expense_currency;*;expense_members;*;expense_info" + "\n"
//            for (var j = 0; j < listModel_tempProjectExpenses.count; j++) {
//                toBackupString += listModel_tempProjectExpenses.get(j).id_unixtime_created
//                        + ";*;" + listModel_tempProjectExpenses.get(j).date_time
//                        + ";*;" + listModel_tempProjectExpenses.get(j).expense_payer
//                        + ";*;" + listModel_tempProjectExpenses.get(j).expense_name
//                        + ";*;" + listModel_tempProjectExpenses.get(j).expense_sum
//                        + ";*;" + listModel_tempProjectExpenses.get(j).expense_currency
//                        + ";*;" + listModel_tempProjectExpenses.get(j).expense_members
//                        + ";*;" + listModel_tempProjectExpenses.get(j).expense_info
//                        + "\n"
//            }
//            //console.log(toBackupString)

//            // store in file and give notification
//            idTextFileBackup.source = backupFilePath
//            idTextFileBackup.text = toBackupString
//            notificationString = backupFilePath

//            //show notification somehow on top
//            var headlineText = qsTr("Backup successful")
//            var detailText = qsTr("File saved to:") + backupFilePath
//            var triggerHiding = false
//            notificationBackup.showBig(headlineText, detailText)
//        }
//    }

//    function restoreProjectExpenses(selectedPath, selectedAction) {
//        idTextFileBackup.source = selectedPath
//        var loadTextString = (idTextFileBackup.text)
//        var pos = loadTextString.lastIndexOf("\n") // ToDo: remove last occurance of "\n"
//        var loadTextLinesArray = (loadTextString.substring(0,pos) + loadTextString.substring(pos+1)).split("\n")
//        var tempStringExistingId_unixtime = ""
//        //var tempProjectIndex = listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp

//        // plausibility check on lines 0 to 2
//        if (loadTextLinesArray[2] === "id_unixtime_created;*;date_time;*;expense_payer;*;expense_name;*;expense_sum;*;expense_currency;*;expense_members;*;expense_info") {
//            var tempProjectIndex = listModel_allProjects.get(idComboboxProject.currentIndex).project_id_timestamp

//            // if REPLACE: delete old entries in project-specific expense table in database, otherwise just MERGE
//            if (selectedAction === "replace") {
//                Storage.deleteAllExpenses(tempProjectIndex)
//            } else { //"merge"
//                // generate expenses list for this project
//                var currentProjectEntries = Storage.getAllExpenses( activeProjectID_unixtime, "none")
//                if (currentProjectEntries !== "none") {
//                    for (var i = 0; i < currentProjectEntries.length ; i++) {
//                        tempStringExistingId_unixtime += (currentProjectEntries[i][0]).toString() + ";"
//                    }
//                }
//                //console.log(tempStringExistingId_unixtime)
//            }

//            // fill with backup entries
//            for (i = 3; i < loadTextLinesArray.length; i++) {
//                var tempExpenseLineArray = (loadTextLinesArray[i]).split(";*;")
//                var project_name_table = tempProjectIndex
//                var id_unixtime_created = tempExpenseLineArray[0]
//                var date_time = tempExpenseLineArray[1]
//                var expense_payer = tempExpenseLineArray[2]
//                var expense_name = tempExpenseLineArray[3]
//                var expense_sum = tempExpenseLineArray[4]
//                var expense_currency = tempExpenseLineArray[5]
//                var expense_members = tempExpenseLineArray[6]
//                var expense_info = tempExpenseLineArray[7]

//                if (selectedAction === "replace") {
//                    Storage.setExpense(project_name_table, id_unixtime_created.toString(), date_time.toString(), expense_name, expense_sum, expense_currency, expense_info, expense_payer, expense_members)
//                    //console.log("entering DB -> " + tempExpenseLineArray)
//                } else {
//                    // check for double entries, only add if not existent
//                    if (tempStringExistingId_unixtime.indexOf(id_unixtime_created.toString()) === -1) {
//                        Storage.setExpense(project_name_table, id_unixtime_created.toString(), date_time.toString(), expense_name, expense_sum, expense_currency, expense_info, expense_payer, expense_members)
//                        //console.log("entering DB -> " + tempExpenseLineArray)
//                    }
//                }
//            }

//            //show notification somehow on top
//            var headlineText = qsTr("Backup successfully restored.")
//            if (selectedAction === "replace") {
//                var detailText = qsTr("Project expenses have been overwritten by backup-file expenses.")
//            } else {
//                detailText = qsTr("Project expenses have been merged with backup-file expenses.")
//            }
//            var triggerHiding = false
//            notificationBackup.showBig(headlineText, detailText)

//            // set this flag when the current project gets merged or replaced with a backup
//            if ( Number(tempProjectIndex) === Number(activeProjectID_unixtime) ) {
//                updateEvenWhenCanceled = true
//            }
//        } else {
//            //show notification somehow on top
//            headlineText = qsTr("Validity check failed.")
//            detailText = qsTr("This backup file does not seem to be created by Expenditure:") + " " + backupFilePath
//            triggerHiding = false
//            notificationBackup.showBig(headlineText, detailText)
//        }
//    }
}
