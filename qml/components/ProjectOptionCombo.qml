/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.ComboData 1.0

ComboBox {
    id: root
    width: parent.width

    property ProjectData selectedProject
    property string role

    property var indexOfData
    property int currentData
    ComboData { dataRole: 'value' }

    onCurrentDataChanged: {
        if (currentData != selectedProject[role]) {
            selectedProject[role] = currentData
        }
    }

    onSelectedProjectChanged: {
        root.currentIndex = root.indexOfData(selectedProject[role])
    }

    Component.onCompleted: {
        currentIndex = indexOfData(selectedProject[role])
    }
}
