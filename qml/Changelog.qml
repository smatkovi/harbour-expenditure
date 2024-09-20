/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Mirian Margiani
 */

import QtQuick 2.0
import "modules/Opal/About"

ChangelogList {
    ChangelogItem {
        version: "1.0.0-1"
        date: "2024-09-20"
        author: "Mirian Margiani (ichthyosaurus)"
        paragraphs: [
            "- Complete rewrite of the app with a brand new user interface, improved stability, and many new features<br>" +
            "- Added support for fees and exchange rates per transaction<br>" +
            "- Added changelog<br>" +
            "- Added support for backups using MyBackup<br>" +
            "- Updated readme with details on required permissions<br>" +
            "- and much more"
        ]
    }
    ChangelogItem {
        version: "0.4-1"
        date: "2023-12-16"
        author: "yajo10"
        paragraphs: [
            "- Added translations: Swedish<br>" +
            "- Improved handling of decimal separators when adding a new entry"
        ]
    }
    ChangelogItem {
        version: "0.3-1"
        date: "2023-11-25"
        author: "yajo10"
        paragraphs: [
            "- Added Chum packaging<br>" +
            "- Added more details on the About page"
        ]
    }
    ChangelogItem {
        version: '0.2.'
        date: "2022-01-01"
        author: "Tobias Planitzer"
        paragraphs: [
            '- Last release by the original author'
        ]
    }
}
