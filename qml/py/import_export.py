# coding: utf-8
#
# This file is part of harbour-expenditure.
# SPDX-FileCopyrightText: 2024 Mirian Margiani
# SPDX-License-Identifier: GPL-3.0-or-later
#

import shutil
import csv
import math
from pathlib import Path


try:
    import pyotherside
    HAVE_SIDE = True
except ImportError:
    HAVE_SIDE = False

    class pyotherside:
        def send(*args, **kwargs):
            print(f"pyotherside.send: {args} {kwargs}")


EXPENSES_COLUMNS = [
    'rowid',
    # 'project', -- not exported
    'utc_time',
    'local_time',
    'local_tz',
    'name',
    'info',
    'sum',
    'currency',
    'rate',
    'percentage_fees',
    'fixed_fees',
    'payer',
    'beneficiaries',
]


def log(*args) -> None:
    pyotherside.send('log', ' '.join([str(x) for x in args]))


def move_aside(path):
    turn = 0

    if not Path(path).exists():
        return

    while True:
        bak = str(path) + '.bak' + (f'~{turn}~' if turn > 0 else '')

        if Path(bak).exists():
            turn += 1
        else:
            shutil.move(str(path), bak)
            break


def doExport(entries, outputFolder, name, currency) -> str:
    outputPath = Path(outputFolder) / f'{name} [{currency}].csv'
    move_aside(outputPath)

    with open(outputPath, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)

        writer.writerow(EXPENSES_COLUMNS)

        for entry in entries:
            writer.writerow([entry[x] for x in EXPENSES_COLUMNS])

    return str(outputPath)


def doImport(inputPath: str) -> None:
    if not Path(inputPath).is_file():
        return None

    with open(inputPath, newline='') as csvfile:
        reader = csv.DictReader(csvfile)

        missingFields = [x for x in EXPENSES_COLUMNS if x not in reader.fieldnames]

        if missingFields:
            pyotherside.send('Fields missing: ' + missingFields.join(', '))
            return None

        # rowid is skipped: imported entries get new IDs
        result = [{a: x[a] for a in EXPENSES_COLUMNS if a != 'rowid'} for x in reader]
        return result

    return None


def doCreateReport(metadata, entries, rates,
                   payments, benefits, balances,
                   totalPayments, settlement,
                   missingRates, detailed: bool) -> str:
    cur = metadata['baseCurrency']

    report = f'''
# Project: {metadata['name']} [{cur}]

total expenses: {totalPayments} {cur}

## Project members
    '''.strip()

    for k, v in balances.items():
        report += '\n\n\n'
        report += f'''
### {k}

- paid: {payments[k]} {cur}
- received: {benefits[k]} {cur}
- balance: {balances[k]} {cur}
        '''.strip()

    if settlement and len(settlement) > 0:
        report += '\n\n\n'
        report += '## Settlement suggestion\n\n'

        for group in settlement:
            report += f'''
- {group['from']} pays {group['to']} the sum of {group['value']} {cur}
            '''.strip()

    if missingRates and len(missingRates) > 0:
        report += '\n\n\n'
        report += '## Missing exchange rates\n\n'
        report += 'The following exchange rates are undefined. A rate ' + \
                  'of 1.00 has been used in calculations.\n\n'
        report += 'Missing: ' + ', '.join(missingRates)

    if detailed:
        report += '\n\n\n'
        report += '## Detailed spendings'

        for x in entries:
            report += '\n\n'
            report += f'''
**{x['name']}**:
- date: {x['local_time']} ({x['local_tz']})
- price: {x['sum']} {x['currency']}
- paid by {x['payer']} for {x['beneficiaries_string']}
            '''.strip()

            if x['rate'] and not math.isnan(x['rate']):
                log(x['rate'], type(x['rate']))
                report += f"\n- exchange rate: {x['rate']}"

            if x['fixed_fees'] and not math.isnan(x['fixed_fees']):
                report += f"\n- fixed fees: {x['fixed_fees']} {cur}"

            if x['percentage_fees'] and not math.isnan(x['percentage_fees']):
                report += f"\n- percentage fees: {x['percentage_fees']}"

            if x['info']:
                report += f"\n- additional info: {x['info']}"

    report = report.strip()
    report += '\n'

    log(report)

    return report
