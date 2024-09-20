/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Mirian Margiani
 */

// this script is not a library
.import "storage.js" as Storage

var _project = null
var _expenses = null
var _exchangeRates = {}
var _baseCurrency = ''

var _payments = {}
var _benefits = {}
var _totalPayments = 0

var _peopleMap = {}
var _peopleArr = []


function calculate(projectData) {
    _reset(projectData)
    _collectSumsAndPeople()

    console.log("calculation results:")
    console.log(JSON.stringify(_payments))
    console.log(JSON.stringify(_benefits))
    console.log(JSON.stringify(_peopleArr))

    return {
        expenses: _expenses,
        baseCurrency: _baseCurrency,
        payments: _payments,
        benefits: _benefits,
        totalPayments: _totalPayments,
        people: _peopleArr,
    }
}

function _reset(projectData) {
    _project = projectData
    _expenses = Storage.getProjectEntries(_project.rowid)
    _exchangeRates = _project.exchangeRates
    _baseCurrency = _project.baseCurrency

    _payments = {}
    _benefits = {}
    _totalPayments = 0
    _peopleMap = {}
    _peopleArr = []
}

function _collectSumsAndPeople() {
    for (var i in _expenses) {
        var x = _expenses[i]

        if (!_payments.hasOwnProperty(x.payer)) {
            _payments[x.payer] = 0
        }

        var convertedSum = _convertToBase(x)
        _totalPayments += convertedSum
        _payments[x.payer] += convertedSum
        var individualBenefit = convertedSum / x.beneficiaries_list.length

        for (var b in x.beneficiaries_list) {
            var bb = x.beneficiaries_list[b]

            if (!_benefits.hasOwnProperty(bb)) {
                _benefits[bb] = 0
            }

            _benefits[bb] += individualBenefit
            _peopleMap[bb] = true
        }

        _peopleMap[x.payer] = true
    }

    for (var p in _peopleMap) {
        if (!_peopleMap.hasOwnProperty(p)) continue
        _peopleArr.push(p)

        var tmp = _benefits[p] || (_benefits[p] = 0)
        tmp = _payments[p] || (_payments[p] = 0)
    }
}

function _convertToBase(expense) {
    var effectiveRate = 1.00

    if (!!expense.rate) {
        effectiveRate = expense.rate
    } else if (_exchangeRates.hasOwnProperty(expense.currency)) {
        effectiveRate = _exchangeRates[expense.currency] || NaN
    } else {
        effectiveRate = NaN
    }

    var price = expense.sum * effectiveRate

    if (!!expense.percentage_fees) {
        price += price / 100 * expense.percentage_fees
    }

    if (!!expense.fixed_fees) {
        price += expense.fixed_fees
    }

    return price
}
