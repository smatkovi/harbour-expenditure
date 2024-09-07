/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/dates.js" as Dates
import "../js/storage.js" as Storage

import "../modules/Opal/Delegates" as D

Page {
    id: page
    allowedOrientations: Orientation.All

    // project specific global variables, loaded when activating a new project
    property double activeProjectID_unixtime : Number(Storage.getSettings("activeProjectID_unixtime", 0))
    property int activeProjectID_listIndex
    property string activeProjectName
    property string activeProjectCurrency : "EUR"
    property string activeProjectAllMembers: ""

    // program specific global variables
    property int sortOrderExpenses : Number(Storage.getSettings("sortOrderExpensesIndex", 0)) // 0=descending, 1=ascending
    property int exchangeRateMode : Number(Storage.getSettings("exchangeRateModeIndex", 0)) // 0=collective, 1=individual
    property string recentlyUsedCurrency : Storage.getSettings("recentlyUsedCurrency", activeProjectCurrency)

    // navigation specific blocking
    property bool updateEvenWhenCanceled : false
    property bool delegateMenuOpen : false


    // autostart
    Component.onCompleted: {
        generateAllProjectsList_FromDB()
        loadActiveProjectInfos_FromDB(activeProjectID_unixtime)
    }

    // XXX this is the new attached page
    // used to add the WritePage for a new entry
    /**
    forwardNavigation: true

    onStatusChanged: {
        if (status == PageStatus.Active) {
            pageStack.pushAttached(Qt.resolvedUrl("ExpenseDialog.qml"),
                                   {'acceptDestination': Qt.resolvedUrl("FirstPage.qml")})
        }
    }
    **/


    // other items, components and pages
    ListModel {
        id: listModel_allProjects
    }
    ListModel {
        id: listModel_activeProjectMembers
    }
    ListModel {
        id: listModel_activeProjectExpenses
        property string sortColumnName: "date_time" //"id_unixtime_created"
        function swap(a,b) {
            if (a<b) {
                move(a,b,1);
                move (b-1,a,1);
            }
            else if (a>b) {
                move(b,a,1);
                move (a-1,b,1);
            }
        }
        function partition(begin, end, pivot) {
            var piv=get(pivot)[sortColumnName];
            swap(pivot, end-1);
            var store=begin;
            var ix;
            for(ix=begin; ix<end-1; ++ix) {
                if (sortOrderExpenses === 1){
                    if(get(ix)[sortColumnName] < piv) {
                        swap(store,ix);
                        ++store;
                    }
                } else { // (sortOrderExpenses === 0)
                    if(get(ix)[sortColumnName] > piv) {
                        swap(store,ix);
                        ++store;
                    }
                }
            }
            swap(end-1, store);
            return store;
        }
        function qsort(begin, end) {
            if(end-1>begin) {
                var pivot=begin+Math.floor(Math.random()*(end-begin));

                pivot=partition( begin, end, pivot);

                qsort(begin, pivot);
                qsort(pivot+1, end);
            }
        }
        function quick_sort() {
            qsort(0,count)
        }

        onCountChanged: {
            quick_sort()
        }
    }
    ListModel {
        id: listModel_exchangeRates
    }
    ListModel {
        id: listModel_activeProjectResults
        property string sortColumnName : "expense_sum"
        property string sortOrderResults : "desc" //"asc"
        function swap(a,b) {
            if (a<b) {
                move(a,b,1);
                move (b-1,a,1);
            }
            else if (a>b) {
                move(b,a,1);
                move (a-1,b,1);
            }
        }
        function partition(begin, end, pivot) {
            var piv=get(pivot)[sortColumnName];
            swap(pivot, end-1);
            var store=begin;
            var ix;
            for(ix=begin; ix<end-1; ++ix) {
                if (sortOrderResults === "asc"){
                    if(get(ix)[sortColumnName] < piv) {
                        swap(store,ix);
                        ++store;
                    }
                } else { // (sortOrderResults === "desc")
                    if(get(ix)[sortColumnName] > piv) {
                        swap(store,ix);
                        ++store;
                    }
                }
            }
            swap(end-1, store);
            return store;
        }
        function qsort(begin, end) {
            if(end-1>begin) {
                var pivot=begin+Math.floor(Math.random()*(end-begin));

                pivot=partition( begin, end, pivot);

                qsort(begin, pivot);
                qsort(pivot+1, end);
            }
        }
        function quick_sort(orderDirection) {
            sortOrderResults = orderDirection
            qsort(0,count)
        }
    }

    SettingsPage {
        id: settingsPage
    }
    CalcPage {
        id: calcPage
    }
    BannerAddExpense {
        id: bannerAddExpense
    }
    Component {
        id: datePickerComponent
        DatePickerDialog {}
    }
    Component {
        id: timePickerComponent
        TimePickerDialog {}
    }

    // main page, current project
    SilicaListView {
        id: idSilicaListView
        anchors.fill: parent

        property date currentSectionDate: new Date(currentSection)

        header: PageHeader {
            title: qsTr("Expenses")
            description: activeProjectID_unixtime !== 0 ?
                            "%1 [%2]".arg(activeProjectName).arg(activeProjectCurrency) :
                            ""
        }

        // XXX this is the new scrollbar
        property Item _scrollbar: null

        VerticalScrollDecorator {
            flickable: idSilicaListView //root
            visible: !idSilicaListView._scrollbar
        }

        Component.onCompleted: {
            try {
                _scrollbar = Qt.createQmlObject("
                    import QtQuick 2.0
                    import %1 1.0 as Private
                    import '../js/dates.js' as Dates
                    Private.Scrollbar {
                        text: idSilicaListView.currentSectionDate.toLocaleString(Qt.locale(), Dates.dateNoYearFormat)
                        description: idSilicaListView.currentSectionDate.toLocaleString(Qt.locale(), 'yyyy')
                        headerHeight: idSilicaListView.headerItem ? idSilicaListView.headerItem.height : 0
                    }".arg("Sailfish.Silica.private"), idSilicaListView, 'Scrollbar')
            } catch (e) {
                if (!_scrollbar) {
                    console.warn(e)
                    console.warn('[BUG] failed to load customized scrollbar')
                    console.warn('[BUG] this probably means the private API has changed')
                }
            }
        }

        PullDownMenu {
            id: idPulldownMenu
            quickSelect: true

            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(settingsPage)
            }
            MenuItem {
                text: qsTr("Calculate")
                enabled: activeProjectID_unixtime !== 0
                onClicked: pageStack.animatorPush(calcPage)
            }
            MenuItem {
                text: qsTr("Add")
                enabled: activeProjectID_unixtime !== 0
                onClicked: bannerAddExpense.notify( Theme.rgba(Theme.highlightDimmerColor, 1), Theme.itemSizeLarge, "new", activeProjectID_unixtime, 0 )
            }
        }

        ViewPlaceholder {
            enabled: activeProjectID_unixtime === 0 // listModel_allProjects.count === 0
            text: qsTr("Create new project.")
            hintText: qsTr("Nothing loaded yet.")
        }

        model: listModel_activeProjectExpenses

        delegate: D.ThreeLineDelegate {
            id: idListItem
            minContentHeight: Theme.itemSizeExtraLarge

            title: new Date(Number(date_time)).toLocaleString(Qt.locale(), Dates.timeFormat)
            text: expense_name
            description: {
                // FIXME linebreak causes binding loop on "height"
                (expense_info + "\n" +
                (expense_members === activeProjectAllMembers ?
                     "for everyone" :
                     "for %2".arg(expense_members.split(" ||| ").join(", "))
                )).trim()
            }

            textLabel.wrapped: true
            descriptionLabel.wrapped: true
            titleLabel.font.pixelSize: Theme.fontSizeExtraSmall
            textLabel.font.pixelSize: Theme.fontSizeSmall
            descriptionLabel.font.pixelSize: Theme.fontSizeExtraSmall

            rightItem: D.DelegateInfoItem {
                title: expense_payer
                text: Number(expense_sum).toLocaleString(Qt.locale("de_CH")) // XXX translate
                description: expense_currency.toString()
                minWidth: 1.2 * Theme.itemSizeMedium
                textLabel.font.pixelSize: Theme.fontSizeMedium
            }

            onClicked: openMenu()

            menu: ContextMenu {
                id: idContextMenu

                MenuItem {
                    text: qsTr("Edit")
                    onClicked: {
                        bannerAddExpense.notify( Theme.rgba(Theme.highlightDimmerColor, 1), Theme.itemSizeLarge, "edit", activeProjectID_unixtime, id_unixtime_created )
                    }
                }
                MenuItem {
                    text: qsTr("Remove")
                    onClicked: {
                        var ident = id_unixtime_created
                        var idx = index
                        idListItem.remorseDelete(function() {
                            Storage.deleteExpense(activeProjectID_unixtime, ident)
                            listModel_activeProjectExpenses.remove(idx)
                        })
                    }
                }
            }
        }

        section {
            property: "section_string"
            delegate: SectionHeader {
                text: new Date(section).toLocaleString(Qt.locale(), Dates.fullDateFormat)
            }
        }

        footer: Item { width: parent.width; height: Theme.horizontalPageMargin }
    }

    function generateAllProjectsList_FromDB() {
        listModel_allProjects.clear()
        var allProjectsOverview = Storage.getAllProjects("none")
        //console.log(allProjectsOverview)
        if (allProjectsOverview !== "none") {
            for (var i = 0; i < allProjectsOverview.length ; i++) {

                listModel_allProjects.append({
                    project_id_timestamp : Number(allProjectsOverview[i][0]),
                    project_name : allProjectsOverview[i][1],
                    project_members : allProjectsOverview[i][2],
                    project_recent_payer_boolarray : allProjectsOverview[i][3],
                    project_recent_beneficiaries_boolarray : allProjectsOverview[i][4],
                    project_base_currency : allProjectsOverview[i][5],
                })
            }
        }
    }
    function loadActiveProjectInfos_FromDB(activeProjectID_unixtime) {
        //console.log( "loading project: " + Number(activeProjectID_unixtime) )
        listModel_activeProjectMembers.clear()
        listModel_activeProjectExpenses.clear()
        for (var j = 0; j < listModel_allProjects.count ; j++) {
            //console.log("in listmodel: " + Number(listModel_allProjects.get(j).project_id_timestamp) )
            // only use active project infos
            if ( Number(listModel_allProjects.get(j).project_id_timestamp) === Number(activeProjectID_unixtime) ) {
                // find active project name and currency
                activeProjectName = listModel_allProjects.get(j).project_name
                activeProjectID_listIndex = j
                activeProjectCurrency = listModel_allProjects.get(j).project_base_currency

                // generate active project members list
                var activeProjectMembersArray = (listModel_allProjects.get(j).project_members).split(" ||| ")
                activeProjectAllMembers = listModel_allProjects.get(j).project_members
                var activeProjectRecentPayerBoolArray = (listModel_allProjects.get(j).project_recent_payer_boolarray).split(" ||| ")
                var activeProjectRecentBeneficiariesBoolArray = (listModel_allProjects.get(j).project_recent_beneficiaries_boolarray).split(" ||| ")
                for (var i = 0; i < activeProjectMembersArray.length ; i++) {
                    listModel_activeProjectMembers.append({
                        member_name : activeProjectMembersArray[i],
                        member_isBeneficiary : activeProjectRecentBeneficiariesBoolArray[i],
                        member_isPayer : activeProjectRecentPayerBoolArray[i],
                    })
                }

                // generate active project expenses list
                var currentProjectEntries = Storage.getAllExpenses( activeProjectID_unixtime, "none")
                if (currentProjectEntries !== "none") {
                    for (i = 0; i < currentProjectEntries.length ; i++) {
                        listModel_activeProjectExpenses.append({
                            id_unixtime_created : Number(currentProjectEntries[i][0]).toFixed(0),
                            date_time : Number(currentProjectEntries[i][1]).toFixed(0),
                            section_string: new Date(Number(currentProjectEntries[i][1])).toLocaleString(Qt.locale(), 'yyyy-MM-dd'),
                            expense_name : currentProjectEntries[i][2],
                            expense_sum : Number(currentProjectEntries[i][3]).toFixed(2),
                            expense_currency : currentProjectEntries[i][4],
                            expense_info : currentProjectEntries[i][5],
                            expense_payer : currentProjectEntries[i][6],
                            expense_members : currentProjectEntries[i][7],
                        })
                    }
                }
            }
        }
    }

}
