# coding: utf-8
#
# This file is part of harbour-expenditure.
# SPDX-FileCopyrightText: 2024 Mirian Margiani
# SPDX-License-Identifier: GPL-3.0-or-later
#

import shutil
import csv
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
    'payer',
    'beneficiaries'
]


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


def doExport(entries, outputFolder, name, currency):
    outputPath = Path(outputFolder) / f'{name} [{currency}].csv'
    move_aside(outputPath)

    with open(outputPath, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)

        writer.writerow(EXPENSES_COLUMNS)

        for entry in entries:
            writer.writerow([entry[x] for x in EXPENSES_COLUMNS])

    return outputPath


def doImport(inputPath):
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
