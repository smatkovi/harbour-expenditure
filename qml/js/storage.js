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

DB.dbName = "Bible_DB"
DB.dbDescription = "BibleDatabaseComplete"
DB.dbSize = 2000000

DB.dbMigrations = [
    [0.1, '\
        CREATE TABLE IF NOT EXISTS settings_table(
            setting TEXT UNIQUE, value TEXT
        );
        CREATE TABLE IF NOT EXISTS projects_table(
            project_id_timestamp TEXT,
            project_name TEXT,
            project_members TEXT,
            project_recent_payer_boolarray TEXT,
            project_recent_beneficiaries_boolarray TEXT,
            project_base_currency TEXT
        );
        CREATE TABLE IF NOT EXISTS exchange_rates_table(
            exchange_rate_currency TEXT,
            exchange_rate_value TEXT
        );
    '],
    [0.2, function(tx){
        var table = DB.defaultFor(DB._keyValueSettingsTable, "__local_settings")
        tx.executeSql('DROP TABLE IF EXISTS %1;'.arg(table));
        DB._createSettingsTable(tx);
        tx.executeSql('INSERT INTO %1(key, value) \
            SELECT setting, value FROM settings_table;'.arg(table))
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
                    expense_payer,
                    expense_members
                FROM table_%2;
            '.arg(projectId))

            tx.executeSql('DROP TABLE table_%1;'.arg(projectId))
            tx.executeSql('UPDATE expenses SET project = ?, local_tz = ? WHERE project = ?;',
                          [projectId, timezone, "project"])
        }

        var dates = tx.executeSql('SELECT DISTINCT utc_time FROM expenses;')

        console.log("> rewriting", dates.rows.length, "dates...")

        for (var k = 0; k < dates.rows.length; ++k) {
            var oldTime = dates.rows.item(k).utc_time
            var date = new Date(Number(oldTime))
            var utc = date.toISOString()
            var local = date.toLocaleString(Qt.locale(), Dates.dbDateFormat)
            console.log(oldTime, "->", utc, "UTC /", local, timezone, "LOCAL")

            tx.executeSql('UPDATE expenses SET \
                utc_time = ?, local_time = ? WHERE utc_time = ?;',
                [utc, local, oldTime])
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
        '.arg(DB._keyValueSettingsTable))
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
                payer, beneficiaries
            ) SELECT
                NULL,
                project, utc_time, local_time, local_tz,
                name, info, sum, currency,
                payer, beneficiaries
            FROM expenses;
        ')
        tx.executeSql('DROP TABLE expenses;')
        tx.executeSql('ALTER TABLE expenses_temp RENAME TO expenses;')
    }],

    // add new versions here...
    //
    // remember: versions must be numeric, e.g. 0.1 but not 0.1.1
]

//
// BEGIN Expenditure database functions
//

//function removeFullTable(tableName) {
//    DB.simpleQuery('DROP TABLE IF EXISTS ?', [tableName]);
//}

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

//// all projects available
//function setProject(project_id_timestamp,
//                    project_name,
//                    project_members,
//                    project_recent_payer_boolarray,
//                    project_recent_beneficiaries_boolarray,
//                    project_base_currency) {
//    var res = DB.simpleQuery('INSERT OR REPLACE INTO projects_table VALUES (?,?,?,?,?,?);',
//                             [project_id_timestamp,
//                              project_name,
//                              project_members,
//                              project_recent_payer_boolarray,
//                              project_recent_beneficiaries_boolarray,
//                              project_base_currency
//                             ])

//    if (res.rowsAffected > 0) {
//        return "OK"
//    } else {
//        return "Error"
//    }
//}

//function updateProject(project_id_timestamp,
//                       project_name,
//                       project_members,
//                       project_recent_payer_boolarray,
//                       project_recent_beneficiaries_boolarray,
//                       project_base_currency) {
//    var res = DB.simpleQuery('\
//            UPDATE projects_table SET \
//                project_name = ?,
//                project_members = ?,
//                project_recent_payer_boolarray = ?,
//                project_recent_beneficiaries_boolarray = ?,
//                project_base_currency = ?
//            WHERE project_id_timestamp = ?
//        ', [
//             project_name,
//             project_members,
//             project_recent_payer_boolarray,
//             project_recent_beneficiaries_boolarray,
//             project_base_currency,
//             project_id_timestamp
//        ])

//    if (res.rowsAffected > 0) {
//        return "OK"
//    } else {
//        return "Error"
//    }
//}

//function updateField_Project(project_id_timestamp, field_name, new_value) {
//    var db = DB.getDatabase();
//    var res = "";
//    db.transaction(function(tx) {
//        var rs = tx.executeSql('UPDATE projects_table SET ' + field_name + '= ? WHERE project_id_timestamp = ?;',
//                               [new_value, project_id_timestamp]);
//        if (rs.rowsAffected > 0) {
//            res = "OK";
//        } else {
//            res = "Error";
//        }
//    }
//    );
//    return res;
//}

//function deleteProject(project_id_timestamp) {
//    var db = DB.getDatabase();
//    var res = "";
//    db.transaction(function(tx) {
//        var rs = tx.executeSql('DELETE FROM projects_table WHERE project_id_timestamp= ?;',
//                               [project_id_timestamp]);
//        if (rs.rowsAffected > 0) {
//            res = "OK";
//        } else {
//            res = "Error";
//        }
//    }
//    );
//    removeFullTable("table_" + project_id_timestamp)
//    return res;
//}

function getProjects(projectDataComponent, parent) {
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
            lastBeneficiaries: item.last_Beneficiaries,
            ratesMode: item.rates_mode,
        }
    }

    return null
}

function _setLastPeople(project, payer, beneficiaries) {
    DB.simpleQuery('\
        UPDATE projects
        SET last_payer = ?, last_beneficiaries = ?
        WHERE rowid = ?',
        [payer, joinMembersList(beneficiaries), project])
}

function _getProjectMembers(ident) {
    var res = DB.simpleQuery('\
        SELECT members FROM projects WHERE rowid = ? LIMIT 1;
    ', [ident])

    return res.rows.item(0).members
}

function _makeProjectEntry(entryRow, projectMembers) {
    var item = entryRow

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
        payer: item.payer,
        beneficiaries: item.beneficiaries,
        beneficiaries_string: item.beneficiaries === projectMembers ?
            qsTr("everyone") : splitMembersList(item.beneficiaries).join(', '),
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

//function getAllProjects( default_value ) {
//    var db = DB.getDatabase();
//    var res=[];
//    try {
//        db.transaction(function(tx) {
//            var rs = tx.executeSql('SELECT * FROM projects_table;')
//            if (rs.rows.length > 0) {
//                for (var i = 0; i < rs.rows.length; i++) {
//                    res.push([rs.rows.item(i).project_id_timestamp,
//                              rs.rows.item(i).project_name,
//                              rs.rows.item(i).project_members,
//                              rs.rows.item(i).project_recent_payer_boolarray,
//                              rs.rows.item(i).project_recent_beneficiaries_boolarray,
//                              rs.rows.item(i).project_base_currency,
//                             ])
//                }
//            } else {
//                res = default_value;
//            }
//        })
//    } catch (err) {
//        //console.log("Database " + err);
//        res = default_value;
//    };
//    return res
//}

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


// all expenes in current project

//
// BEGIN Expenses
//

function addExpense(projectIdent,
                    utc_time, local_time, local_tz,
                    name, info, sum, currency, payer, beneficiaries) {
    var res = DB.simpleQuery('\
        INSERT INTO expenses(
            project,
            utc_time, local_time, local_tz,
            name, info, sum, currency, payer, beneficiaries
        ) VALUES (
            ?,
            ?, ?, ?,
            ?, ?, ?, ?, ?, ?
        );
    ', [projectIdent,
        utc_time, local_time, local_tz,
        name, info, sum, currency, payer, joinMembersList(beneficiaries)])

    var newEntry = DB.simpleQuery('\
        SELECT rowid, * FROM expenses \
        WHERE rowid = ?
        LIMIT 1;', [res.insertId])

    var allMembers = _getProjectMembers(projectIdent)

    _setLastPeople(projectIdent, payer, beneficiaries)

    return _makeProjectEntry(newEntry.rows.item(0), allMembers)
}

function updateExpense(projectIdent, rowid,
                       utc_time, local_time, local_tz,
                       name, info, sum, currency, payer, beneficiaries) {
    var res = DB.simpleQuery('\
        UPDATE expenses SET
            project = ?,
            utc_time = ?, local_time = ?, local_tz = ?,
            name = ?, info = ?, sum = ?, currency = ?, payer = ?, beneficiaries = ?
        WHERE project = ? AND rowid = ?;
    ', [projectIdent,
        utc_time, local_time, local_tz,
        name, info, sum, currency, payer, joinMembersList(beneficiaries),
        projectIdent, rowid])

    var changedEntry = DB.simpleQuery('\
        SELECT rowid, * FROM expenses \
        WHERE rowid = ?
        LIMIT 1;', [rowid])

    var allMembers = _getProjectMembers(projectIdent)

    _setLastPeople(projectIdent, payer, beneficiaries)

    return _makeProjectEntry(changedEntry.rows.item(0), allMembers)
}

//function setExpense( project_name_table, id_unixtime_created, date_time, expense_name, expense_sum, expense_currency, expense_info, expense_payer, expense_members ) {
//    var db = DB.getDatabase();
//    var res = "";
//    db.transaction(function(tx) {
//        tx.executeSql('CREATE TABLE IF NOT EXISTS table_' + project_name_table + ' (id_unixtime_created TEXT, \
//                                                                                    date_time TEXT, \
//                                                                                    expense_name TEXT, \
//                                                                                    expense_sum TEXT, \
//                                                                                    expense_currency TEXT, \
//                                                                                    expense_info TEXT, \
//                                                                                    expense_payer TEXT, \
//                                                                                    expense_members TEXT)' );
//        var rs = tx.executeSql('INSERT OR REPLACE INTO table_' + project_name_table + ' VALUES (?,?,?,?,?,?,?,?);', [ id_unixtime_created,
//                                                                                                                     date_time,
//                                                                                                                     expense_name,
//                                                                                                                     expense_sum,
//                                                                                                                     expense_currency,
//                                                                                                                     expense_info,
//                                                                                                                     expense_payer,
//                                                                                                                     expense_members ]);
//        if (rs.rowsAffected > 0) {
//            res = "OK";
//            //console.log("project info found and updated")
//        } else {
//            res = "Error";
//        }
//    }
//    );
//    return res;
//}

//function updateExpense ( project_name_table, id_unixtime_created, date_time, expense_name, expense_sum, expense_currency, expense_info, expense_payer, expense_members ) {
//    var db = DB.getDatabase();
//    var res = "";
//    db.transaction(function(tx) {
//        tx.executeSql('CREATE TABLE IF NOT EXISTS table_' + project_name_table + ' (id_unixtime_created TEXT, \
//                                                                            date_time TEXT, \
//                                                                            expense_name TEXT, \
//                                                                            expense_sum TEXT, \
//                                                                            expense_currency TEXT, \
//                                                                            expense_info TEXT, \
//                                                                            expense_payer TEXT, \
//                                                                            expense_members TEXT)' );
//        var rs = tx.executeSql('UPDATE table_' + project_name_table
//                               + ' SET date_time="' + date_time
//                               + '", expense_name="' + expense_name
//                               + '", expense_sum="' + expense_sum
//                               + '", expense_currency="' + expense_currency
//                               + '", expense_info="' + expense_info
//                               + '", expense_payer="' + expense_payer
//                               + '", expense_members="' + expense_members
//                               + '" WHERE id_unixtime_created=' + id_unixtime_created + ';');
//        if (rs.rowsAffected > 0) {
//            res = "OK";
//        } else {
//            res = "Error";
//        }
//    }
//    );
//    return res;
//}

function deleteExpense(projectId, entryId) {
    DB.simpleQuery('DELETE FROM expenses WHERE project = ? AND rowid = ?;',
                   [projectId, entryId])
}

//function deleteAllExpenses (project_id_timestamp) {
//    var db = DB.getDatabase();
//    var res = "";
//    db.transaction(function(tx) {
//        tx.executeSql('CREATE TABLE IF NOT EXISTS table_' + project_id_timestamp + ' (id_unixtime_created TEXT, \
//                                                                            date_time TEXT, \
//                                                                            expense_name TEXT, \
//                                                                            expense_sum TEXT, \
//                                                                            expense_currency TEXT, \
//                                                                            expense_info TEXT, \
//                                                                            expense_payer TEXT, \
//                                                                            expense_members TEXT)' );
//        var rs = tx.executeSql('DELETE FROM table_' + project_id_timestamp + ';');
//        if (rs.rowsAffected > 0) {
//            res = "OK";
//        } else {
//            res = "Error";
//        }
//    }
//    );
//    return res;
//}

//function getAllExpenses( project_name_table, default_value ) {
//    var db = DB.getDatabase();
//    var res=[];
//    try {
//        db.transaction(function(tx) {
//            var rs = tx.executeSql('SELECT * FROM table_'+ project_name_table + ';');
//            if (rs.rows.length > 0) {
//                for (var i = 0; i < rs.rows.length; i++) {
//                    res.push([rs.rows.item(i).id_unixtime_created,
//                              rs.rows.item(i).date_time,
//                              rs.rows.item(i).expense_name,
//                              rs.rows.item(i).expense_sum,
//                              rs.rows.item(i).expense_currency,
//                              rs.rows.item(i).expense_info,
//                              rs.rows.item(i).expense_payer,
//                              rs.rows.item(i).expense_members,
//                             ])
//                }
//            } else {
//                res = default_value;
//            }
//        })
//    } catch (err) {
//        //console.log("Database " + err);
//        res = default_value;
//    };
//    return res
//}
