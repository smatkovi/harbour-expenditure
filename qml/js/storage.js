/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Mirian Margiani
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 */

.pragma library
.import "storage_helper.js" as DB
.import "dates.js" as Dates

//
// BEGIN Database configuration
//

function dbOk() { return DB.dbOk }

// The name of the database is a historical relic
// but it cannot be changed due to limitations in Qt.
DB.dbName = "Bible_DB"
DB.dbDescription = "BibleDatabaseComplete"
DB.dbSize = 2000000

DB.dbMigrations = [
    // Database versions do not correspond to app versions.

    [0.1, function(tx){
        // This is the original database schema of all
        // app versions until 0.4. Expenses were stored
        // in dynamic tables called "table_<project-id>"
        // that were created on-demand.
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS settings_table(
                setting TEXT UNIQUE, value TEXT
            );')
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS projects_table(
                project_id_timestamp TEXT,
                project_name TEXT,
                project_members TEXT,
                project_recent_payer_boolarray TEXT,
                project_recent_beneficiaries_boolarray TEXT,
                project_base_currency TEXT
            );')
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS exchange_rates_table(
                exchange_rate_currency TEXT,
                exchange_rate_value TEXT
            );')
    }],
    [0.2, function(tx){
        tx.executeSql('DROP TABLE IF EXISTS %1;'.arg(DB.settingsTable));
        DB.createSettingsTable(tx);
        tx.executeSql('INSERT INTO %1(key, value) \
            SELECT setting, value FROM settings_table;'.arg(DB.settingsTable))
        tx.executeSql('DROP TABLE settings_table;');
    }],
    [0.3, function(tx){
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS expenses(
                project INTEGER NOT NULL,
                utc_time TEXT NOT NULL,
                local_time TEXT NOT NULL,
                local_tz TEXT NOT NULL,
                name TEXT DEFAULT "",
                info TEXT DEFAULT "",
                sum REAL,
                currency TEXT NOT NULL,
                rate REAL,
                percentage_fees REAL,
                fixed_fees REAL,
                payer TEXT NOT NULL,
                beneficiaries TEXT NOT NULL
            );
        ')

        var projects = tx.executeSql('SELECT rowid, project_id_timestamp FROM projects_table;')
        var timezone = Dates.getTimezone()

        console.log("> rewriting", projects.rows.length, "projects...")

        for (var i = 0; i < projects.rows.length; i++) {
            var projectId = projects.rows.item(i).project_id_timestamp
            var projectRowId = projects.rows.item(i).rowid

            // old expenses schema
            tx.executeSql('\
                CREATE TABLE IF NOT EXISTS table_%1 (
                    id_unixtime_created TEXT,
                    date_time TEXT,
                    expense_name TEXT,
                    expense_sum TEXT,
                    expense_currency TEXT,
                    expense_info TEXT,
                    expense_payer TEXT,
                    expense_members TEXT
                );
            '.arg(projectId));

            // new expenses schema
            tx.executeSql('\
                INSERT INTO expenses(
                    project,
                    utc_time,
                    local_time,
                    local_tz,
                    name,
                    info,
                    sum,
                    currency,
                    rate,
                    percentage_fees,
                    fixed_fees,
                    payer,
                    beneficiaries)
                SELECT
                    "project",
                    date_time,
                    date_time,
                    "",
                    expense_name,
                    expense_info,
                    expense_sum,
                    expense_currency,
                    NULL,
                    NULL,
                    NULL,
                    expense_payer,
                    expense_members
                FROM table_%2;
            '.arg(projectId))

            tx.executeSql('DROP TABLE table_%1;'.arg(projectId))
            tx.executeSql('UPDATE expenses SET project = ?, local_tz = ? WHERE project = ?;',
                          [projectId, timezone, "project"])
        }

        var expenses = tx.executeSql('SELECT DISTINCT utc_time, beneficiaries FROM expenses;')
        console.log("> rewriting", expenses.rows.length, "dates and beneficiary lists...")

        for (var k = 0; k < expenses.rows.length; ++k) {
            var oldTime = expenses.rows.item(k).utc_time
            var date = new Date(Number(oldTime))
            var utc = date.toISOString()
            var local = date.toLocaleString(Qt.locale(), Dates.dbDateFormat)
            console.log(oldTime, "->", utc, "UTC /", local, timezone, "LOCAL")

            tx.executeSql('UPDATE expenses SET \
                utc_time = ?, local_time = ? WHERE utc_time = ?;',
                [utc, local, oldTime])
        }

        function formatBeneficiaries(oldString) {
            var array = DB.defaultFor(oldString || '', '').split(' ||| ').filter(
                        function(e){return e});

            if (array.length > 0) {
                // without outer ' ||| ' - they are added later!
                return array.sort().join(' ||| ')
            }

            return ''
        }

        for (var x = 0; x < expenses.rows.length; ++x) {
            var oldBenefs = expenses.rows.item(x).beneficiaries
            var newBenefs = formatBeneficiaries(oldBenefs)
            console.log(oldBenefs, " RAW ->", newBenefs, "CLEAN")

            tx.executeSql('UPDATE expenses SET \
                beneficiaries = ? WHERE beneficiaries = ?;',
                [newBenefs, oldBenefs])
        }
    }],
    [0.4, function(tx){
        // The rowid column is created explicitly here because
        // it is used as foreign key in other tables. Autoincrement
        // is not necessary because all data referencing a project
        // is deleted when the project is deleted.
        //
        // https://sqlite.org/lang_createtable.html#rowid
        // https://sqlite.org/autoinc.html
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS projects(
                rowid INTEGER PRIMARY KEY,
                name TEXT,
                base_currency TEXT,
                members TEXT,
                last_currency TEXT,
                last_payer TEXT,
                last_beneficiaries TEXT,
                rates_mode INTEGER,
                fees_mode INTEGER,
                project_id_timestamp TEXT
            );
        ')
        tx.executeSql('\
            INSERT INTO projects(
                rowid,
                name,
                base_currency,
                members,
                last_currency,
                last_payer,
                last_beneficiaries,
                rates_mode,
                fees_mode,
                project_id_timestamp
            ) SELECT
                NULL,
                project_name,
                project_base_currency,
                project_members,
                project_base_currency,
                project_recent_payer_boolarray,
                project_recent_beneficiaries_boolarray,
                0,
                0,
                project_id_timestamp
            FROM projects_table;
        ')
        tx.executeSql('\
            UPDATE expenses
            SET project = (
                SELECT projects.rowid FROM projects
                WHERE expenses.project = projects.project_id_timestamp
            ) WHERE EXISTS (
                SELECT projects.rowid FROM projects
                WHERE expenses.project = projects.project_id_timestamp
            );
        ')
        tx.executeSql('\
            UPDATE %1
            SET value = (
                SELECT projects.rowid FROM projects
                WHERE %1.key = "activeProjectID_unixtime"
                    AND %1.value = CAST(projects.project_id_timestamp as INTEGER)
            ) WHERE %1.key = "activeProjectID_unixtime" AND EXISTS (
                SELECT projects.rowid FROM projects
                WHERE %1.key = "activeProjectID_unixtime"
                    AND %1.value = CAST(projects.project_id_timestamp as INTEGER)
            )
        '.arg(DB.settingsTable))
        tx.executeSql('ALTER TABLE projects DROP COLUMN project_id_timestamp;')
        tx.executeSql('DROP TABLE projects_table;')

        var projects = tx.executeSql('\
            SELECT rowid, members, last_payer, last_beneficiaries
            FROM projects;').rows
        console.log("> rewriting", projects.length, "member lists...")

        // Rewrite recently used member lists in project metadata
        // from bool-arrays to the actual member names
        for (var i = 0; i < projects.length; ++i) {
            var item = projects.item(i)
            var members = item.members.split(' ||| ')

            var lastPayer = ''
            var lastBeneficiaries = []

            var payersBool = item.last_payer.split(' ||| ')
            var beneBool = item.last_beneficiaries.split(' ||| ')

            for (var k in members) {
                if (payersBool[k] == 'true') {
                    lastPayer = members[k]
                }

                if (beneBool[k] == 'true') {
                    lastBeneficiaries.push(members[k])
                }
            }

            lastBeneficiaries = joinMembersList(lastBeneficiaries)
            members = joinMembersList(members)

            tx.executeSql('\
                UPDATE projects SET
                    members = ?,
                    last_payer = ?,
                    last_beneficiaries = ?
                WHERE rowid = ?
            ', [members, lastPayer, lastBeneficiaries, item.rowid])
        }
    }],
    [0.5, function(tx){
        // Rewrite member lists in expenses to the new format:
        // required for renaming members using REPLACE LIKE
        tx.executeSql('\
            UPDATE expenses
            SET beneficiaries = (" ||| " || expenses.beneficiaries || " ||| ");
        ')

        // Rewrite expenses table with foreign key constraint
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS expenses_temp(
                rowid INTEGER PRIMARY KEY,
                project INTEGER NOT NULL,
                utc_time TEXT NOT NULL,
                local_time TEXT NOT NULL,
                local_tz TEXT NOT NULL,
                name TEXT DEFAULT "",
                info TEXT DEFAULT "",
                sum REAL DEFAULT 0.0,
                rate REAL DEFAULT NULL,
                percentage_fees REAL DEFAULT NULL,
                fixed_fees REAL DEFAULT NULL,
                currency TEXT NOT NULL,
                payer TEXT NOT NULL,
                beneficiaries TEXT NOT NULL,

                FOREIGN KEY (project)
                REFERENCES projects (rowid)
                    ON UPDATE CASCADE
                    ON DELETE CASCADE
            );
        ')
        tx.executeSql('\
            INSERT INTO expenses_temp(
                rowid,
                project, utc_time, local_time, local_tz,
                name, info, sum, currency,
                rate, percentage_fees, fixed_fees,
                payer, beneficiaries
            ) SELECT
                NULL,
                project, utc_time, local_time, local_tz,
                name, info, sum, currency,
                rate, percentage_fees, fixed_fees,
                payer, beneficiaries
            FROM expenses;
        ')
        tx.executeSql('DROP TABLE expenses;')
        tx.executeSql('ALTER TABLE expenses_temp RENAME TO expenses;')
    }],
    [0.6, function(tx){
        tx.executeSql('\
            DELETE FROM %1 WHERE
                   key = "sortOrderExpensesIndex"
                OR key = "exchangeRateModeIndex"
                OR key = "interativeScrollbarMode"
                OR key = "recentlyUsedCurrency"
        ;'.arg(DB.settingsTable))
        tx.executeSql('\
            UPDATE %1
            SET key = "active_project"
            WHERE key = "activeProjectID_unixtime"
        ;'.arg(DB.settingsTable))
    }],

    // add new versions here...
    //
    // remember: versions must be numeric, e.g. 0.1 but not 0.1.1
]

//
// BEGIN Expenditure database functions
//

var fieldSeparator = ' ||| '

function splitMembersList(string) {
    // Important: do not use this in migrations!
    // This function might change over time. However, migrations
    // must explicitly state what they do.
    return DB.defaultFor(string || '', '').split(' ||| ').filter(function(e){return e});
}

function joinMembersList(array) {
    // Important: do not use this in migrations!
    // This function might change over time. However, migrations
    // must explicitly state what they do.
    array = DB.defaultFor(array, [])

    if (array.length > 0) {
        return ' ||| %1 ||| '.arg(array.sort().join(' ||| '))
    }

    return ''
}


//
// BEGIN Settings
//

function setSetting(key, value) {
    return DB.setSetting(key, value)
}

function getSetting(key, fallback) {
    return DB.getSetting(key, fallback)
}

function getSortOrder() {
    return 'DESC'
}


//
// BEGIN Projects
//

function getActiveProjectId() {
    var ident = getSetting('active_project', -1000)

    if (!_projectExists(ident)) {
        return -1000
    }

    return ident
}

function setActiveProjectId(ident) {
    if (!_projectExists(ident)) {
        ident = -1000
    }

    setSetting('active_project', ident)
}

function _projectExists(ident) {
    if (ident < 0) {
        return false
    }

    var res = DB.simpleQuery('\
        SELECT rowid FROM projects
        WHERE rowid = ?
        LIMIT 1;', [ident])

    if (res.rows.length > 0) {
        return true
    }

    return false
}

function saveProjects(projectDataArray) {
    // This function takes an array of ProjectData objects
    // as returned by getProjects().
    // - All projects that are currently in the database but
    //   that are NOT in this array will be DELETED.
    // - All projects in the database will be updated with new
    //   metadata from the array.

    var res = DB.readQuery('SELECT rowid FROM projects;')
    var currentProjects = []
    var keptProjects = {}
    var newRowids = []

    for (var i = 0; i < res.rows.length; ++i) {
        var item = res.rows.item(i)
        keptProjects[item.rowid] = false
        currentProjects.push(item.rowid)
    }

    for (var k in projectDataArray) {
        var kRowid = projectDataArray[k].rowid
        var newIdent = -1

        if (kRowid < 0) {
            // new project
            newIdent = _saveNewProject(projectDataArray[k])
        } else {
            // updated project
            keptProjects[projectDataArray[k].rowid] = true
            newIdent = _updateProject(projectDataArray[k])
        }

        for (var imported in projectDataArray[k].importedExpenses) {
            var e = projectDataArray[k].importedExpenses[imported]
            _addExpenseDirectly(newIdent,
                                e.utc_time, e.local_time, e.local_tz,
                                e.name, e.info, e.sum, e.currency,
                                e.payer, splitMembersList(e.beneficiaries))
        }

        newRowids.push(newIdent)
    }

    var deletedProjects = currentProjects.filter(function(item){
        return keptProjects[item] === false
    })

    for (var x in deletedProjects) {
        _deleteProject(deletedProjects[x])
    }

    return newRowids
}

function _saveNewProject(projectData) {
    var res = DB.simpleQuery('\
        INSERT INTO projects(
            rowid,
            name, base_currency,
            members,
            last_currency, last_payer,
            last_beneficiaries,
            rates_mode, fees_mode
        ) VALUES (
            NULL,
            ?, ?, ?,
            ?, ?, ?,
            ?, ?
        );
    ', [projectData.name, projectData.baseCurrency,
        joinMembersList(projectData.members),
        projectData.lastCurrency, projectData.lastPayer,
        joinMembersList(projectData.lastBeneficiaries),
        projectData.ratesMode, projectData.feesMode])

    return res.insertId
}

function _renameProjectMember(project, oldName, newName) {
    DB.simpleQuery('\
        UPDATE expenses
        SET beneficiaries = REPLACE(beneficiaries, " ||| " || ? || " ||| ", " ||| " || ? || " ||| ")
        WHERE beneficiaries LIKE "% ||| " || ? || " ||| %"
            AND project = ?
    ;', [oldName, newName, oldName, project])
    DB.simpleQuery('\
        UPDATE expenses
        SET payer = ?
        WHERE payer = ? AND project = ?
    ;', [newName, oldName, project])
}

function _updateProject(projectData) {
    var newMembers = []
    var renamedMembers = projectData.renamedMembers

    for (var i in projectData.members) {
        var member = projectData.members[i]
        if (!renamedMembers.hasOwnProperty(member)) {
            renamedMembers[member] = member
        }
    }

    for (var k in projectData.renamedMembers) {
        if (renamedMembers.hasOwnProperty(k)) {
            newMembers.push(renamedMembers[k])

            if (k !== renamedMembers[k]) {
                _renameProjectMember(projectData.rowid, k, renamedMembers[k])
            }
        }
    }

    var lastBeneficiaries = projectData.lastBeneficiaries.filter(
        function(e){ return newMembers.indexOf(e) >= 0 })
    var lastPayer = newMembers.indexOf(projectData.lastPayer) >= 0 ?
        projectData.lastPayer : ''

    DB.simpleQuery('\
        UPDATE projects SET
            name = ?, base_currency = ?,
            members = ?,
            last_currency = ?, last_payer = ?,
            last_beneficiaries = ?,
            rates_mode = ?, fees_mode = ?
        WHERE rowid = ?;
    ', [projectData.name, projectData.baseCurrency,
        joinMembersList(newMembers),
        projectData.lastCurrency, lastPayer,
        joinMembersList(lastBeneficiaries),
        projectData.ratesMode, projectData.feesMode,
        projectData.rowid])

    return projectData.rowid
}

function _deleteProject(rowid) {
    rowid = DB.defaultFor(rowid, -1)

    if (rowid < 0) return

    console.log("deleting project id", rowid, "...")
    DB.simpleQuery('DELETE FROM projects WHERE rowid = ?;', [rowid])
}

function getProjects(projectDataComponent, parent) {
    // This function takes a ProjectData component and a
    // parent QML object. It returns an array of ProjectData
    // objects parented to "parent".

    var res = DB.readQuery('SELECT rowid FROM projects;')
    var projects = []

    for (var i = 0; i < res.rows.length; ++i) {
        var item = res.rows.item(i)
        projects.push(projectDataComponent.createObject(
            parent, {rowid: item.rowid}))
    }

    return projects
}

function getProjectMetadata(ident) {
    var res = DB.readQuery(
        'SELECT * FROM projects WHERE rowid = ? LIMIT 1;',
        [ident])

    if (res.rows.length > 0) {
        var item = res.rows.item(0)
        return {
            ident: item.rowid,
            name: item.name,
            baseCurrency: item.base_currency,
            members: splitMembersList(item.members),
            lastCurrency: item.last_currency,
            lastPayer: item.last_payer,
            lastBeneficiaries: splitMembersList(item.last_beneficiaries),
            ratesMode: item.rates_mode,
            feesMode: item.fees_mode
        }
    }

    return null
}

function _setLastInfo(project, currency, payer, beneficiaries) {
    // Only store names of active project members. When editing
    // old entries, it's possible that there are still names of
    // since deleted members. To avoid keeping these names floating
    // around, they have to be filtered out here.
    var members = splitMembersList(_getProjectMembers(project))
    beneficiaries = beneficiaries.filter(
        function(e){ return members.indexOf(e) >= 0 })

    DB.simpleQuery('\
        UPDATE projects
        SET last_currency = ?, last_payer = ?, last_beneficiaries = ?
        WHERE rowid = ?',
        [currency, payer, joinMembersList(beneficiaries),
         project])
}

function _getProjectMembers(ident) {
    // This returns a formatted string, not an array!

    var res = DB.simpleQuery('\
        SELECT members FROM projects WHERE rowid = ? LIMIT 1;
    ', [ident])

    return res.rows.item(0).members
}

function _makeProjectEntry(entryRow, projectMembers) {
    var item = entryRow
    var beneficiaries = splitMembersList(item.beneficiaries)

    return {
        rowid: item.rowid,
        utc_time: item.utc_time,
        local_time: item.local_time,
        local_tz: item.local_tz,
        section_string: Dates.formatDate(item.local_time, 'yyyy-MM-dd'),
        name: item.name,
        info: item.info,
        sum: item.sum,
        currency: item.currency,
        rate: item.rate || 1.00,
        percentage_fees: item.percentage_fees || 0.00,
        fixed_fees: item.fixed_fees || 0.00,
        payer: item.payer,

        // Beneficiaries are not split into an array because
        // that would be converted into a ListModel in QML,
        // which is impractical to work with in this case.
        beneficiaries: item.beneficiaries,
        beneficiaries_list: beneficiaries,

        // The screen presentation string is created here
        // to avoid having to recalculate it when bindings are evaluated.
        beneficiaries_string: item.beneficiaries === projectMembers ?
            qsTr("everyone") : beneficiaries.join(', '),
    }
}

function getProjectEntries(ident) {
    var order = getSortOrder()

    var res = DB.simpleQuery('\
        SELECT rowid, * FROM expenses \
        WHERE project = ?
        ORDER BY utc_time %2;'.arg(order), [ident])
    var entries = []

    var allMembers = _getProjectMembers(ident)

    if (res.rows.length === 0) return []

    for (var i = 0; i < res.rows.length; i++) {
        entries.push(_makeProjectEntry(res.rows.item(i), allMembers))
    }

    return entries
}


// all exchange rates used
function countExchangeRateOccurances (exchange_rate_currency, default_value) {
    var db = DB.getDatabase();
    var res="";
    try {
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT count(*) AS some_info FROM exchange_rates_table WHERE exchange_rate_currency=?;', [exchange_rate_currency]);
            if (rs.rows.length > 0) {
                res = rs.rows.item(0).some_info;
            } else {
                res = default_value;
            }
        })
    } catch (err) {
        //console.log("Database " + err);
        res = default_value;
    };
    return res
}

function setExchangeRate( exchange_rate_currency, exchange_rate_value ) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        var rs = tx.executeSql('INSERT OR REPLACE INTO ' + 'exchange_rates_table' + ' VALUES (?,?);', [exchange_rate_currency, exchange_rate_value ]);
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    return res;
}

function updateExchangeRate( exchange_rate_currency, exchange_rate_value ) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        var rs = tx.executeSql('UPDATE exchange_rates_table SET exchange_rate_value="' + exchange_rate_value + '" WHERE exchange_rate_currency="' + exchange_rate_currency + '";');
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    return res;
}

function getExchangeRate(exchange_rate_currency, default_value) {
    var db = DB.getDatabase();
    var res=[];
    try {
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT * FROM '+ 'exchange_rates_table' +' WHERE exchange_rate_currency=?;', [exchange_rate_currency]);
            if (rs.rows.length > 0) {
                for (var i = 0; i < rs.rows.length; i++) {
                    res.push(rs.rows.item(i).exchange_rate_value)
                }
            } else {
                res = default_value;
            }
        })
    } catch (err) {
        //console.log("Database " + err);
        res = default_value;
    };
    return res
}


//
// BEGIN Expenses
//

function _addExpenseDirectly(projectIdent,
                             utc_time, local_time, local_tz,
                             name, info, sum, currency,
                             rate, percentageFees, fixedFees,
                             payer, beneficiaries) {
    var res = DB.simpleQuery('\
        INSERT INTO expenses(
            project,
            utc_time, local_time, local_tz,
            name, info, sum, currency,
            rate, percentage_fees, fixed_fees,
            payer, beneficiaries
        ) VALUES (
            ?,
            ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?,
            ?, ?
        );
    ', [projectIdent,
        utc_time, local_time, local_tz,
        name, info, sum, currency,
        rate, percentageFees, fixedFees,
        payer, joinMembersList(beneficiaries)])

    return res
}

function addExpense(projectIdent,
                    utc_time, local_time, local_tz,
                    name, info, sum, currency,
                    rate, percentageFees, fixedFees,
                    payer, beneficiaries) {
    var res = _addExpenseDirectly(projectIdent,
                                  utc_time, local_time, local_tz,
                                  name, info, sum, currency,
                                  rate, percentageFees, fixedFees,
                                  payer, beneficiaries)

    var newEntry = DB.simpleQuery('\
        SELECT rowid, * FROM expenses \
        WHERE rowid = ?
        LIMIT 1;', [res.insertId])

    var allMembers = _getProjectMembers(projectIdent)

    _setLastInfo(projectIdent, currency, payer, beneficiaries)

    return _makeProjectEntry(newEntry.rows.item(0), allMembers)
}

function updateExpense(projectIdent, rowid,
                       utc_time, local_time, local_tz,
                       name, info, sum, currency,
                       rate, percentageFees, fixedFees,
                       payer, beneficiaries) {
    var res = DB.simpleQuery('\
        UPDATE expenses SET
            project = ?,
            utc_time = ?, local_time = ?, local_tz = ?,
            name = ?, info = ?, sum = ?, currency = ?,
            rate = ?, percentage_fees = ?, fixed_fees = ?,
            payer = ?, beneficiaries = ?
        WHERE project = ? AND rowid = ?;
    ', [projectIdent,
        utc_time, local_time, local_tz,
        name, info, sum, currency,
        rate, percentageFees, fixedFees,
        payer, joinMembersList(beneficiaries),
        projectIdent, rowid])

    var changedEntry = DB.simpleQuery('\
        SELECT rowid, * FROM expenses \
        WHERE rowid = ?
        LIMIT 1;', [rowid])

    var allMembers = _getProjectMembers(projectIdent)

    _setLastInfo(projectIdent, currency, payer, beneficiaries)

    return _makeProjectEntry(changedEntry.rows.item(0), allMembers)
}

function deleteExpense(projectId, entryId) {
    DB.simpleQuery('DELETE FROM expenses WHERE project = ? AND rowid = ?;',
                   [projectId, entryId])
}
