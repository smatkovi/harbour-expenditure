/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Opal.Delegates 1.0 as D
import Opal.SmartScrollbar 1.0 as S

import "../components"
import "../js/dates.js" as Dates
import "../js/math.js" as M

Page {
    id: root
    allowedOrientations: Orientation.All
    forwardNavigation: !noProjectPlaceholder.enabled

    onStatusChanged: {
        if (status == PageStatus.Active) {
            pageStack.pushAttached(Qt.resolvedUrl("ExpenseDialog.qml"), {
                'acceptDestination': root,
                'acceptDestinationAction': PageStackAction.Pop
            })
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        opacity: busyPlaceholder.enabled ? 0.5 : 1.0

        Behavior on opacity { FadeAnimator {} }

        header: PageHeader {
            title: qsTr("Expenses")

            // the description must never be empty because the
            // header height is not properly recalculated if the
            // description is added later
            description: appWindow.activeProject.active ?
                             "%1 [%2]".arg(appWindow.activeProject.name)
                                      .arg(appWindow.activeProject.baseCurrency) :
                             " "
        }

        S.SmartScrollbar {
            flickable: listView
            property date date: new Date(listView.currentSection)
            text: date.toLocaleString(Qt.locale(), Dates.dateNoYearFormat)
            description: date.toLocaleString(Qt.locale(), 'yyyy')
            smartWhen: listView.contentHeight > Screen.height
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Calculate")
                enabled: visible
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("CalcPage.qml"))
                visible: appWindow.activeProject.active && !emptyPlaceholder.enabled
            }
        }

        ViewPlaceholder {
            id: busyPlaceholder
            enabled: appWindow.loading
            verticalOffset: -listView.originY - height

            BusyIndicator {
                anchors.centerIn: parent
                running: parent.enabled
                size: BusyIndicatorSize.Large
            }
        }

        ViewPlaceholder {
            id: emptyPlaceholder
            enabled: !appWindow.loading &&
                     appWindow.activeProject.active &&
                     listView.count == 0
            text: qsTr("No entries yet")
            hintText: qsTr("Swipe to the left to add an entry.")
        }

        ViewPlaceholder {
            id: noProjectPlaceholder
            enabled: !appWindow.loading &&
                     !appWindow.activeProject.active
            text: qsTr("Add a project")
            hintText: qsTr("Pull down to open the settings page.")
        }

        model: appWindow.activeProject.expenses

        // this improves scrolling performance but at the
        // cost of longer loading times...
        cacheBuffer: 100 * Screen.height

        delegate: D.ThreeLineDelegate {
            id: item
            showOddEven: false

            title: Dates.formatDate(local_time, Dates.timeFormat, local_tz)
            text: name
            description: {
                // FIXME linebreak causes binding loop on "height"
                (info + "\n" + qsTr(
                     "for %1", "as in “this payment was for Jane, John, and Jim”, " +
                     "with plural based on the number of beneficiaries",
                     beneficiaries_list.count).arg(beneficiaries_string)).trim()
            }

            readonly property string effectiveRate: {
                if (!!rate) {
                    rate
                } else if (appWindow.activeProject.exchangeRates.hasOwnProperty(currency)) {
                    appWindow.activeProject.exchangeRates[currency] || ''
                } else {
                    ''
                }
            }

            textLabel.wrapped: true
            descriptionLabel.wrapped: true
            titleLabel.font.pixelSize: Theme.fontSizeExtraSmall
            textLabel.font.pixelSize: Theme.fontSizeSmall
            descriptionLabel.font.pixelSize: Theme.fontSizeExtraSmall

            rightItem: D.DelegateInfoItem {
                title: payer
                text: M.format(sum, appWindow.activeProject.precision) + ((!!percentage_fees || !!fixed_fees) ? '*' : '')
                description: currency.toString()
                textLabel.font.pixelSize: Theme.fontSizeMedium
                alignment: Qt.AlignRight
            }

            onClicked: openMenu()

            menu: Component {
                ContextMenu {
                    MenuLabel {
                        visible: currency !== appWindow.activeProject.baseCurrency ||
                                 (!M.isNotNum(item.effectiveRate) && !M.value(item.effectiveRate).eq(1))
                        text: {
                            if (M.isNotNum(item.effectiveRate)) {
                                qsTr("set %1 → %2 exchange rate in project settings")
                                    .arg(currency).arg(appWindow.activeProject.baseCurrency)
                            } else {
                                '%1 %2 × %3 = %4 %5'
                                    .arg(M.format(sum, appWindow.activeProject.precision))
                                    .arg(currency)
                                    .arg(M.format(item.effectiveRate, 4))
                                    .arg(M.format(M.value(sum).times(item.effectiveRate).toString(),
                                                  appWindow.activeProject.precision))
                                    .arg(appWindow.activeProject.baseCurrency)
                            }
                        }
                    }
                    MenuLabel {
                        visible: !M.isNotNum(item.effectiveRate) && (!!fixed_fees || !!percentage_fees)
                        text: {
                            if (!visible) return ''

                            var precision = appWindow.activeProject.precision
                            var text = ''
                            var sumConv = M.value(sum).times(item.effectiveRate)
                            var total = M.value(sum).times(item.effectiveRate)

                            if (!!percentage_fees) {
                                var percentCalc = sumConv.times(M.value(percentage_fees).div(100))
                                total = total.plus(percentCalc)
                                text += "+ %1 %2 (%3%) "
                                    .arg(M.format(percentCalc, precision))
                                    .arg(appWindow.activeProject.baseCurrency)
                                    .arg(M.format(percentage_fees, precision))
                            }
                            if (!!fixed_fees) {
                                total = total.plus(fixed_fees)
                                text += "+ %1 %2 "
                                    .arg(M.format(fixed_fees, precision))
                                    .arg(appWindow.activeProject.baseCurrency)
                            }

                            text += "= %1 %2"
                                .arg(M.format(total, precision))
                                .arg(appWindow.activeProject.baseCurrency)
                            return text
                        }
                    }
                    MenuItem {
                        text: qsTr("Edit")
                        onClicked: {
                            var initialValues = {
                                index: index, rowid: rowid,
                                utc_time: utc_time, local_time: local_time, local_tz: local_tz,
                                name: name, info: info, sum: sum,
                                rate: rate, percentageFees: percentage_fees, fixedFees: fixed_fees,
                                currency: currency, payer: payer,
                                initialBeneficiaries: beneficiaries
                            }
                            var properties = initialValues
                            properties['initialValuesReadOnly'] = initialValues
                            pageStack.push(Qt.resolvedUrl("ExpenseDialog.qml"), properties)
                        }
                    }
                    MenuItem {
                        text: qsTr("Remove")
                        onClicked: appWindow.activeProject.removeEntry(item, rowid, index)
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

        footer: Spacer { size: Theme.horizontalPageMargin }
    }
}
