/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0

TimePickerDialog {
    property int maximumHour: 24
    property int maximumMinute: 60

    function _isValid() {
        return hour < maximumHour || (
                     hour == maximumHour &&
                     minute <= maximumMinute)
    }

    onDone: {
        if (result == DialogResult.Accepted && !_isValid()) {
            Notices.show(qsTr("The time has been reset. " +
                              "It cannot be in the future."), 2500, Notice.Bottom)
            hour = maximumHour
            minute = maximumMinute
        }
    }
}
