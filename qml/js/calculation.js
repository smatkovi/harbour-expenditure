/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 Mirian Margiani
 */

// note: this script is not a library
//
// TODO either convert this to WorkerScript or rewrite it in Python

.import "storage.js" as Storage
.import "math.js" as M

var _project = null
var _expenses = null
var _members = []
var _exchangeRates = {}
var _baseCurrency = ''
var _settlementPrecision = 2

var _payments = {}
var _benefits = {}
var _balances = {}
var _totalPayments = M.value('0.00')
var _settlement = []
var _missingRates = {}

var _peopleMap = {}
var _peopleArr = []


function calculate(projectData, directDebts) {
    console.log("calculating...")
    _reset(projectData)
    _collectSumsAndPeople()
    _splitDues(directDebts)

    if (!_validate()) {
        _settlement = null
        console.log("failed to calculate a valid settlement suggestion")
    }

    console.log("calculation results:")
    console.log("- project:", projectData.name)
    console.log("- paid:", JSON.stringify(_payments))
    console.log("- received:", JSON.stringify(_benefits))
    console.log("- members:", JSON.stringify(_peopleArr))
    console.log("- settlement:", JSON.stringify(_settlement))

    var missingRatesArr = keys(_missingRates)

    if (missingRatesArr.length > 0) {
        console.log("- missing exchange rates:", JSON.stringify(missingRatesArr))
    }

    _formatResults()

    return {
        expenses: _expenses,
        baseCurrency: _baseCurrency,
        payments: _payments,
        benefits: _benefits,
        balances: _balances,
        totalPayments: _totalPayments,
        settlement: _settlement,
        missingRates: missingRatesArr,
        people: _peopleArr,
    }
}

function defaultFor(arg, val) {
    return typeof arg !== 'undefined' ? arg : val
}

function keys(object) {
    var ret = []

    for(var key in object) {
        if(object.hasOwnProperty(key)) {
            ret.push(key)
        }
    }

    return ret
}

function _reset(projectData) {
    console.log("[calc] resetting...")
    _project = projectData
    var metadata = Storage.getProjectMetadata(_project.rowid)
    _expenses = Storage.getProjectEntries(_project.rowid)
    _members = metadata.members
    _exchangeRates = _project.exchangeRates
    _baseCurrency = metadata.baseCurrency
    _settlementPrecision = _project.precision

    _payments = {}
    _benefits = {}
    _balances = {}
    _totalPayments = M.value('0.00')
    _settlement = []
    _missingRates = {}
    _peopleMap = {}
    _peopleArr = []
}

function _collectSumsAndPeople() {
    console.log("[calc] collecting data...")

    for (var i in _expenses) {
        var x = _expenses[i]

        if (!_payments.hasOwnProperty(x.payer)) {
            _payments[x.payer] = M.value('0.00')
        }

        var convertedSum = _convertToBase(x)
        _totalPayments = _totalPayments.plus(convertedSum)
        _payments[x.payer] = _payments[x.payer].plus(convertedSum)
        var individualBenefit = convertedSum.div(x.beneficiaries_list.length)

        for (var b in x.beneficiaries_list) {
            var bb = x.beneficiaries_list[b]

            if (!_benefits.hasOwnProperty(bb)) {
                _benefits[bb] = M.value('0.00')
            }

            _benefits[bb] = _benefits[bb].plus(individualBenefit)
            _peopleMap[bb] = true
        }

        _peopleMap[x.payer] = true
    }

    for (var m in _members) {
        // ensure all project members are mentioned even if they
        // have no payments/benefits
        //
        // Note: the members array is not used for collecting sums
        // because there may be names mentioned in expenses that
        // have been removed from the active members list.
        _peopleMap[_members[m]] = true
    }

    for (var p in _peopleMap) {
        if (!_peopleMap.hasOwnProperty(p)) continue
        _peopleArr.push(p)

        if (!_benefits.hasOwnProperty(p)) _benefits[p] = M.value('0.00')
        if (!_payments.hasOwnProperty(p)) _payments[p] = M.value('0.00')

        // collect balances: paid minus received
        _balances[p] = _payments[p].minus(_benefits[p])
    }

    _peopleArr.sort()
}

function _convertToBase(expense) {
    var effectiveRate = NaN

    if (!!expense.rate) {
        effectiveRate = M.value(expense.rate)
    } else if (_exchangeRates.hasOwnProperty(expense.currency)
               && !!_exchangeRates[expense.currency]) {
        effectiveRate = M.value(_exchangeRates[expense.currency])
    }

    if (M.isNotNum(effectiveRate)) {
        console.warn("no exchange rate set for", expense.currency, "- using 1.00 instead of", effectiveRate)
        effectiveRate = M.value('1.00')
        _missingRates[expense.currency] = true
    }

    var price = M.value(expense.sum).times(effectiveRate)

    if (!!expense.percentage_fees) {
        price = price.plus(price.div(100).times(expense.percentage_fees))
    }

    if (!!expense.fixed_fees) {
        price = price.plus(expense.fixed_fees)
    }

    return price
}

function _sortMap(map, ascending) {
    var kv = []
    ascending = defaultFor(ascending, true)

    for(var key in map) {
        if (!map.hasOwnProperty(key)) continue
        kv.push({'key': key, 'value': map[key]})
    }

    function sortKeyValue(a, b) {
        return ascending ? a.value.minus(b.value) : b.value.minus(a.value);
    }

    var sorted = kv.sort(sortKeyValue)
    return sorted
}

function _splitDues(directDebts) {
    console.log("[calc] splitting...")

    if (!!directDebts) {
        _settlement = _splitDuesDirectly()
    } else {
        _settlement = _splitDuesOptimized()
    }
}

function _splitDuesDirectly() {
    console.log("[calc] splitting dues (directly)...")

    var settlement = []
    var debts = {}  // debts[from][to] = value

    for (var i in _expenses) {
        var x = _expenses[i]
        var convertedSum = _convertToBase(x)
        var individualDebt = convertedSum.div(x.beneficiaries_list.length)

        for (var b in x.beneficiaries_list) {
            var bb = x.beneficiaries_list[b]

            if (bb === x.payer) {
                continue
            }

            if (!debts.hasOwnProperty(bb)) {
                debts[bb] = {}
            }

            if (!debts[bb].hasOwnProperty(x.payer)) {
                debts[bb][x.payer] = M.value('0.00')
            }

            debts[bb][x.payer] = debts[bb][x.payer].plus(individualDebt)
        }
    }

    for (var from in debts) {
        for (var to in debts[from]) {
            var value = debts[from][to]

            if (debts.hasOwnProperty(to) && debts[to].hasOwnProperty(from)) {
                var reverseValue = debts[to][from]

                if (value.eq(reverseValue)) {
                    debts[from][to] = M.value('0.00')
                    debts[to][from] = M.value('0.00')
                    value = M.value('0.00')
                } else if (value.gt(reverseValue)) {
                    debts[from][to] = value.minus(reverseValue)
                    debts[to][from] = M.value('0.00')
                    value = debts[from][to]
                } else if (reverseValue.gt(value)) {
                    continue
                }
            }

            if (!value.isZero() && !value.isNaN()) {
                settlement.push({
                    from: from,
                    to: to,
                    value: value
                })
            }
        }
    }

    return settlement
}

function _splitDuesOptimized() {
    console.log("[calc] splitting dues (optimized)...")

    // apply a (n-1) algorithm  to settle expenses (how much each person ows to whom)

    var meanValue = M.value('0.00')
    var sortedNames = []
    var sortedValues = []
    var settlement = []

    function prepareArrays() {
        var pendingBalances = {}
        var totalPending = M.value('0.00')

        for (var person in _peopleMap) {
            pendingBalances[person] = (_payments[person] || M.value('0.00')).minus(_benefits[person] || M.value('0.00'))
            totalPending = totalPending.plus(pendingBalances[person])
        }

        var sortedBalances = _sortMap(pendingBalances, true)

        for (var i in sortedBalances) {
            sortedNames.push(sortedBalances[i].key)
            sortedValues.push(sortedBalances[i].value)
        }
    }

    function calculateSettlement() {
        var dataIsSane = true
        var sortedValuesPaid = []

        for (var i in sortedValues) {
            if (M.isNotNum(sortedValues[i])) {
                dataIsSane = false
                break
            }

            sortedValuesPaid.push(sortedValues[i].minus(meanValue))
        }

        if (!dataIsSane) {
            // prevent an endless loop below
            console.error("[calc] encountered invalid value in sorted values, aborting")
            return
        }

        var x = 0
        var y = sortedValues.length - 1
        var debt

        while (x < y) {
            debt = M.BigNumber.minimum(sortedValuesPaid[x].negated(), sortedValuesPaid[y])
            sortedValuesPaid[x] = sortedValuesPaid[x].plus(debt)
            sortedValuesPaid[y] = sortedValuesPaid[y].minus(debt)

            settlement.push({
                from: sortedNames[x],
                to: sortedNames[y],
                value: debt
            })

            if (sortedValuesPaid[x].eq(0)) { x++ }
            if (sortedValuesPaid[y].eq(0)) { y-- }
        }
    }

    console.log("[calc] optimized: preparing...")
    prepareArrays()
    console.log("[calc] optimized: calculating...")
    calculateSettlement()

    console.log("[calc] optimized: done")
    return settlement
}

function _validate() {
    console.log("[calc] validating...")

    var checkBalances = {}
    var success = true

    for (var i in _settlement) {
        var set = _settlement[i]

        if (!checkBalances.hasOwnProperty(set.from))
            checkBalances[set.from] = M.value('0.00')
        if (!checkBalances.hasOwnProperty(set.to))
            checkBalances[set.to] = M.value('0.00')

        checkBalances[set.from] = checkBalances[set.from].minus(set.value)
        checkBalances[set.to] = checkBalances[set.to].plus(set.value)
    }

    console.log("[calc] verification results:")

    for (var j in _balances) {
        if (!_balances.hasOwnProperty(j)) continue

        if (_balances[j].eq(checkBalances[j])) {
            console.log("[   OK]", j, ":", _balances[j])
        } else {
            if (_balances[j].isZero() && !checkBalances.hasOwnProperty(j)) {
                // this person has an even balance and does not appear
                // in the settlement - that's ok
                console.log("[   OK]", j, ":", _balances[j], "| not in settlement")
                continue
            } else if (_balances[j]
                       .minus(checkBalances[j])
                       .abs()
                       .decimalPlaces(_settlementPrecision + 2)
                       .isZero()) {
                // the difference in this settlement is negligible
                console.log("[   OK]", j, ":", _balances[j], "| difference is smaller than settlement precision")
                console.log("        expected", _balances[j], "but got", checkBalances[j])
                console.log("        difference:", _balances[j].minus(checkBalances[j]).toString())
                console.log("        precision:", _settlementPrecision)
                console.log("        rounded to precision:", _balances[j].toFixed(_settlementPrecision))
                continue
            } else {
                console.error("[ERROR]", j, ": settlement failed")
                console.error("        expected", _balances[j], "but got", checkBalances[j])
                console.error("        difference: ", _balances[j].minus(checkBalances[j]).toString())
                success = false
            }
        }
    }

    return success
}

function _formatResults() {
    console.log("[calc] formatting results...")

    // Convert final results to string with fixed precision.
    var rm = M.BigNumber.ROUND_HALF_UP

    // SETTLEMENT
    if (_settlement != null) {
        var filtered = []

        for (var i in _settlement) {
            var set = _settlement[i]

            if (set.value.decimalPlaces(_settlementPrecision).isZero()) {
                continue
            } else {
                filtered.push({
                    from: set.from,
                    to: set.to,
                    value: set.value.toFixed(_settlementPrecision, rm),
                })
            }
        }

        _settlement = filtered
    }

    // REMAINING DICTS
    function formatDict(dict) {
        for (var i in dict) {
            dict[i] = dict[i].toFixed(_settlementPrecision, rm)
        }

        return dict
    }

    _payments = formatDict(_payments)
    _benefits = formatDict(_benefits)
    _balances = formatDict(_balances)

    // REMAINING SINGLE VALUES
    _totalPayments = _totalPayments.toFixed(_settlementPrecision, rm)
}
