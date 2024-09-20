/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0

Label {
    minimumPixelSize: Theme.fontSizeTiny
    fontSizeMode: Text.Fit
    truncationMode: TruncationMode.Fade
    anchors {
        baseline: parent.verticalCenter
        baselineOffset: -Theme.paddingMedium
    }
}
