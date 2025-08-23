/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Mirian Margiani
 */

.pragma library
.import "_bignumber.js" as B

var BigNumber = B.BigNumber

BigNumber.config({
    DECIMAL_PLACES: 30,
    ROUNDING_MODE: BigNumber.ROUND_HALF_EVEN,
    EXPONENTIAL_AT: 1e+9,
    RANGE: 1e+9,
    CRYPTO: false,
    FORMAT: {
        // string to prepend
        prefix: '',
        // string to append
        suffix: '',

        // decimal separator
        decimalSeparator: Qt.locale().decimalPoint,
        // grouping separator of the integer part
        groupSeparator: (Qt.locale().groupSeparator === '.'
                         && Qt.locale().decimalPoint === ',')
                        ? "'" : Qt.locale().groupSeparator,

        // Qt provides no info about these settings so
        // we keep the defaults:

        // primary grouping size of the integer part
        groupSize: 3,
        // secondary grouping size of the integer part
        secondaryGroupSize: 0,

        // grouping separator of the fraction part
        // fractionGroupSeparator: ' ',
        // grouping size of the fraction part
        // fractionGroupSize: 0,
    },
})

function cleanNumberString(string) {
    // Clean a string entered using a locale-aware numbers-only
    // keyboard. Use this with "inputMethodHints: Qt.ImhFormattedNumbersOnly".
    //
    // This function replaces the locale-dependent decimal point
    // with a dot so that the values can be converted to numbers.
    // No validation is performed!

    console.debug("[math] cleaning number input: '" + string + "'")

    var cleaned = string.trim()
    var dp = Qt.locale().decimalPoint || "."
    console.debug("[math] decimal point:", dp)

    if (dp !== '.') {
        cleaned = cleaned.split(dp).join('.')
    }

    // Replace "," as decimal point even if the current locale's
    // decimal point is something else. This is a workaround for
    // users running in one locale but using a keyboard in a different
    // locale. Dot and comma are the most common decimal point characters.
    //
    // This assumes that values are not further formatted, e.g. there
    // must not be any thousands separators etc.
    cleaned = cleaned.replace(/,/g, '.')

    // Entering whitespace isn't possible with Qt's default numbers
    // keyboard but we remove all whitespace anyway in case a number
    // was pasted from the clipboard.
    cleaned.replace(/ /g, '')

    console.debug("[math] cleaned number input:", cleaned)
    return cleaned
}

function expand(string) {
    // Calculate the result of a simple math expression and
    // return a string of the result.
    //
    // Invalid expressions yield an empty string.
    //
    // Only + and - operations are supported. Double minus
    // is treated as x-0-y and not as x-(-y). Grouping is
    // not supported. Whitespace is removed.
    //
    // Use this with "inputMethodHints: Qt.ImhFormattedNumbersOnly".

    var input = cleanNumberString(string)

    console.debug("[math] arithmetic input:", input)

    if (input === '') {
        return ''
    }

    if (!/^[-+0-9.]+$/.test(input)) {
        return ''
    } else if (/--/.test(input)) {
        return ''
    }

    if (input[0] === '+' || input[0] === '-') {
        input = '0' + input
    }

    input += '+0'

    var action = '+'
    var current = '0'
    var result = new BigNumber('0.00')

    for (var i = 0; i < input.length; ++i) {
        var c = input[i]

        if (c === '+' || c === '-') {
            // calculate last result
            if (action === '+') {
                result = result.plus(current)
            } else if (action === '-') {
                result = result.minus(current)
            }

            // start new calculation
            action = c
            current = '0'
        } else {
            current += c
        }
    }

    console.debug("[math] arithmetic result:", result)

    return result.toString()
}

function isNotNum(str) {
    return new BigNumber(str).isNaN()
}

function _callWithPrecision(call, string, minPrecision) {
    if (isNotNum(minPrecision)) {
        minPrecision = 2
    }

    var big = new BigNumber(string)
    var truncated = new BigNumber(big.toFixed(minPrecision))

    if (big.eq(truncated)) {
        return big[call](minPrecision)
    } else {
        return big[call]()
    }
}

function value(string) {
    return new BigNumber(string)
}

function string(string, minPrecision) {
    return _callWithPrecision('toFixed', string, minPrecision)
}

function format(string, minPrecision) {
    return _callWithPrecision('toFormat', string, minPrecision)
}
