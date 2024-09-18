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
import "../js/storage.js" as Storage

Page {
    id: root
    allowedOrientations: Orientation.All
    forwardNavigation: true

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
                enabled: appWindow.activeProject.active
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("CalcPage.qml"))
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
            hintText: qsTr("Swipe to the left to add entries")
        }

        ViewPlaceholder {
            enabled: !appWindow.loading &&
                     !appWindow.activeProject.active
            text: qsTr("Add a project")
            hintText: qsTr("Pull down to open the settings page.")
        }


        model: appWindow.activeProject.expenses

        delegate: D.ThreeLineDelegate {
            id: item
            minContentHeight: Theme.itemSizeExtraLarge

            title: Dates.formatDate(local_time, Dates.timeFormat, local_tz)
            text: name
            description: {
                // FIXME linebreak causes binding loop on "height"
                (info + "\nfor %1".arg(beneficiaries_string)).trim()
            }

            property double effectiveRate: {
                if (!!rate) {
                    rate
                } else if (appWindow.activeProject.exchangeRates.hasOwnProperty(currency)) {
                    appWindow.activeProject.exchangeRates[currency] || NaN
                } else {
                    NaN
                }
            }

            textLabel.wrapped: true
            descriptionLabel.wrapped: true
            titleLabel.font.pixelSize: Theme.fontSizeExtraSmall
            textLabel.font.pixelSize: Theme.fontSizeSmall
            descriptionLabel.font.pixelSize: Theme.fontSizeExtraSmall

            rightItem: D.DelegateInfoItem {
                title: payer
                text: Number(sum).toLocaleCurrencyString(Qt.locale("de_CH"), ' ') + (
                          (!!percentage_fees || !!fixed_fees) ? '*' : '')
                description: currency.toString()
                textLabel.font.pixelSize: Theme.fontSizeMedium
                alignment: Qt.AlignRight
            }

            onClicked: openMenu()

            menu: Component {
                ContextMenu {
                MenuLabel {
                    text: {
                        if (Storage.isSameValue(item.effectiveRate, NaN)) {
                            qsTr("set %1 → %2 exchange rate in project settings")
                                .arg(currency).arg(appWindow.activeProject.baseCurrency)
                        } else {
                            '%1 %2 · %3 = %4 %5'
                                .arg(Number(sum).toLocaleString(Qt.locale("de_CH")))
                                .arg(currency)
                                .arg(item.effectiveRate)
                                .arg(Number(sum * item.effectiveRate).toLocaleString(Qt.locale("de_CH")))
                                .arg(appWindow.activeProject.baseCurrency)
                        }
                    }
                }
                MenuLabel {
                    visible: !isNaN(item.effectiveRate) && (!!fixed_fees || !!percentage_fees)
                    text: {
                        if (!visible) return ''

                        var text = ''
                        var total = sum * item.effectiveRate

                        if (!!percentage_fees) {
                            total += total * (percentage_fees/100)
                            text += "+ %1 %2 (%3%) "
                                .arg(sum * item.effectiveRate * (percentage_fees/100))
                                .arg(appWindow.activeProject.baseCurrency)
                                .arg(Number(percentage_fees).toLocaleString(Qt.locale("de_CH")))
                        }
                        if (!!fixed_fees) {
                            total += fixed_fees
                            text += "+ %1 %2 "
                                .arg(Number(fixed_fees).toLocaleString(Qt.locale("de_CH")))
                                .arg(appWindow.activeProject.baseCurrency)
                        }

                        text += "= %1 %2"
                            .arg(Number(total).toLocaleString(Qt.locale("de_CH")))
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
