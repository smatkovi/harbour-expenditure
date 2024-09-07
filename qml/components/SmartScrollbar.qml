/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0

QtObject {
    id: root

    property Flickable flickable: null
    property string text
    property string description

    property int _headerHeight: !!flickable && flickable.headerItem ?
                                    flickable.headerItem.height : 0

    property VerticalScrollDecorator _fallback: VerticalScrollDecorator {
        parent: root.flickable
        flickable: root.flickable
        visible: !root._scrollbar
    }

    property Item _scrollbar: null

    Component.onCompleted: {
        try {
            _scrollbar = Qt.createQmlObject("
                import QtQuick 2.0
                import %1 1.0 as Private
                Private.Scrollbar {
                    text: root.text
                    description: root.description
                    headerHeight: root._headerHeight
                }".arg("Sailfish.Silica.private"), flickable, 'SmartScrollbar')
        } catch (e) {
            if (!_scrollbar) {
                console.warn(e)
                console.warn('[BUG] failed to load smart scrollbar')
                console.warn('[BUG] this probably means the private API has changed')
            }
        }
    }
}
