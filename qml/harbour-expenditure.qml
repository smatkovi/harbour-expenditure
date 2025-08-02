/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import "js/storage.js" as Storage

import Opal.About 1.0 as A
import Opal.SupportMe 1.0 as M
import Opal.LocalStorage 1.0 as L

import "pages"
import "components"

ApplicationWindow {
    id: appWindow
    initialPage: Component { FirstPage {} }
//    initialPage: Component { SettingsPage {} }
//    initialPage: Component { CalcPage {} }
//    initialPage: Component { FeesRatesPage {} }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")

    property bool loading: true  // only true during startup
    readonly property string appName: "Expenditure"

    readonly property ProjectData activeProject: ProjectData {}
    readonly property var _currentlyEditedEntry: ({})

    function _reopenEditDialog() {
        pageStack.push(Qt.resolvedUrl("pages/ExpenseDialog.qml"), _currentlyEditedEntry)
    }

    function remorseCancelWriting(parentPage, cancelMessage) {
        // This function requires valid data in _currentlyEditedEntry.
        // Populate the cache object before calling this function.

        var remorse = Remorse.popupAction(
                    parentPage, cancelMessage,
                    function(){}, 5000)

        var callback = function () {
            remorse.canceled.disconnect(callback)
            _reopenEditDialog()
        }

        remorse.canceled.connect(callback)
    }

    function maybeLoadDebugData() {
        if (pageStack.previousPage() === null) {
            // Load a project during development when
            // using a custom page as the initial page.
            appWindow.activeProject.rowid = Storage.getActiveProjectId()
            return appWindow.activeProject.rowid
        }

        return null
    }

    // We have to explicitly set the \c _defaultPageOrientations property
    // to \c Orientation.All so the page stack's default placeholder page
    // will be allowed to be in landscape mode. (The default value is
    // \c Orientation.Portrait.) Without this setting, pushing multiple pages
    // to the stack using \c animatorPush() while in landscape mode will cause
    // the view to rotate back and forth between orientations.
    // [as of 2021-02-17, SFOS 3.4.0.24, sailfishsilica-qt5 version 1.1.110.3-1.33.3.jolla]
    _defaultPageOrientations: Orientation.All
    allowedOrientations: Orientation.All

    A.ChangelogNews {
        changelogList: Qt.resolvedUrl("Changelog.qml")
    }

    M.AskForSupport {
        contents: Component {
            MySupportDialog {}
        }
    }

    L.MessageHandler {}

    Component.onCompleted: {
        activeProject.loaded.connect(function(){ appWindow.loading = false; })
        activeProject.rowid = Storage.getActiveProjectId()
    }
}
