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

        // TODO:
        // Recreate this table in a future migration with
        // foreign key once the projects table is finalized.
        //
        //  FOREIGN KEY (project)
        //  REFERENCES projects_table (project_id_timestamp)
        //    ON UPDATE CASCADE
        //    ON DELETE CASCADE

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

    // add new versions here...
    //
    // remember: versions must be numeric, e.g. 0.1 but not 0.1.1
]

//
// BEGIN Expenditure database functions
//

function removeFullTable(tableName) {
    DB.simpleQuery('DROP TABLE IF EXISTS ?', [tableName]);
}


//
// BEGIN Settings
//

function setSettings(setting, value) {
    return DB.setSetting(setting, value)
}

function getSettings(setting, defaultValue) {
    return DB.getSetting(setting, defaultValue)
}

function getSortOrder() {
    return Number(DB.getSetting("sortOrderExpensesIndex", 0)) == Number(0) ?
                'DESC' : 'ASC'
}


//
// BEGIN Projects
//

//// all projects available
function setProject(project_id_timestamp,
                    project_name,
                    project_members,
                    project_recent_payer_boolarray,
                    project_recent_beneficiaries_boolarray,
                    project_base_currency) {
    var res = DB.simpleQuery('INSERT OR REPLACE INTO projects_table VALUES (?,?,?,?,?,?);',
                             [project_id_timestamp,
                              project_name,
                              project_members,
                              project_recent_payer_boolarray,
                              project_recent_beneficiaries_boolarray,
                              project_base_currency
                             ])

    if (res.rowsAffected > 0) {
        return "OK"
    } else {
        return "Error"
    }
}

function updateProject(project_id_timestamp,
                       project_name,
                       project_members,
                       project_recent_payer_boolarray,
                       project_recent_beneficiaries_boolarray,
                       project_base_currency) {
    var res = DB.simpleQuery('\
            UPDATE projects_table SET \
                project_name = ?,
                project_members = ?,
                project_recent_payer_boolarray = ?,
                project_recent_beneficiaries_boolarray = ?,
                project_base_currency = ?
            WHERE project_id_timestamp = ?
        ', [
             project_name,
             project_members,
             project_recent_payer_boolarray,
             project_recent_beneficiaries_boolarray,
             project_base_currency,
             project_id_timestamp
        ])

    if (res.rowsAffected > 0) {
        return "OK"
    } else {
        return "Error"
    }
}

function updateField_Project(project_id_timestamp, field_name, new_value) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        var rs = tx.executeSql('UPDATE projects_table SET ' + field_name + '= ? WHERE project_id_timestamp = ?;',
                               [new_value, project_id_timestamp]);
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    return res;
}

function deleteProject(project_id_timestamp) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        var rs = tx.executeSql('DELETE FROM projects_table WHERE project_id_timestamp= ?;',
                               [project_id_timestamp]);
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    removeFullTable("table_" + project_id_timestamp)
    return res;
}

function getProjectMetadata(ident) {
    var res = DB.readQuery(
        'SELECT * FROM projects_table WHERE project_id_timestamp = ? LIMIT 1;',
        [String(ident)])

    if (res.rows.length > 0) {
        var item = res.rows.item(0)
        return {
            ident: item.project_id_timestamp,
            name: item.project_name,
            members: item.project_members.split(' ||| '),
            lastCurrency: DB.getSetting("recentlyUsedCurrency", item.project_base_currency),
            lastPayer: item.project_recent_payer_boolarray,
            lastBeneficiaries: item.project_recent_beneficiaries_boolarray.split(' ||| '),
            baseCurrency: item.project_base_currency,
        }
    }

    return null
}

function getProjectEntries(ident) {
    var order = getSortOrder()

    var res = DB.simpleQuery('\
        SELECT rowid, * FROM expenses \
        WHERE project = ?
        ORDER BY utc_time %2;'.arg(order), [ident])
    var entries = []

    var allMembers = DB.simpleQuery('\
        SELECT project_members
        FROM projects_table
        WHERE project_id_timestamp = ?
        LIMIT 1;',
        [String(ident)])
    allMembers = allMembers.rows.item(0).project_members

    if (res.rows.length === 0) return []

    for (var i = 0; i < res.rows.length; i++) {
        var item = res.rows.item(i)

        entries.push({
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
            beneficiaries: item.beneficiaries.split(' ||| '),
            beneficiaries_string: item.beneficiaries === allMembers ?
                qsTr("everyone") : item.beneficiaries.split(' ||| ').join(', '),
        })
    }

    return entries
}

function getAllProjects( default_value ) {
    var db = DB.getDatabase();
    var res=[];
    try {
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT * FROM projects_table;')
            if (rs.rows.length > 0) {
                for (var i = 0; i < rs.rows.length; i++) {
                    res.push([rs.rows.item(i).project_id_timestamp,
                              rs.rows.item(i).project_name,
                              rs.rows.item(i).project_members,
                              rs.rows.item(i).project_recent_payer_boolarray,
                              rs.rows.item(i).project_recent_beneficiaries_boolarray,
                              rs.rows.item(i).project_base_currency,
                             ])
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
function setExpense( project_name_table, id_unixtime_created, date_time, expense_name, expense_sum, expense_currency, expense_info, expense_payer, expense_members ) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        tx.executeSql('CREATE TABLE IF NOT EXISTS table_' + project_name_table + ' (id_unixtime_created TEXT, \
                                                                                    date_time TEXT, \
                                                                                    expense_name TEXT, \
                                                                                    expense_sum TEXT, \
                                                                                    expense_currency TEXT, \
                                                                                    expense_info TEXT, \
                                                                                    expense_payer TEXT, \
                                                                                    expense_members TEXT)' );
        var rs = tx.executeSql('INSERT OR REPLACE INTO table_' + project_name_table + ' VALUES (?,?,?,?,?,?,?,?);', [ id_unixtime_created,
                                                                                                                     date_time,
                                                                                                                     expense_name,
                                                                                                                     expense_sum,
                                                                                                                     expense_currency,
                                                                                                                     expense_info,
                                                                                                                     expense_payer,
                                                                                                                     expense_members ]);
        if (rs.rowsAffected > 0) {
            res = "OK";
            //console.log("project info found and updated")
        } else {
            res = "Error";
        }
    }
    );
    return res;
}

function updateExpense ( project_name_table, id_unixtime_created, date_time, expense_name, expense_sum, expense_currency, expense_info, expense_payer, expense_members ) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        tx.executeSql('CREATE TABLE IF NOT EXISTS table_' + project_name_table + ' (id_unixtime_created TEXT, \
                                                                            date_time TEXT, \
                                                                            expense_name TEXT, \
                                                                            expense_sum TEXT, \
                                                                            expense_currency TEXT, \
                                                                            expense_info TEXT, \
                                                                            expense_payer TEXT, \
                                                                            expense_members TEXT)' );
        var rs = tx.executeSql('UPDATE table_' + project_name_table
                               + ' SET date_time="' + date_time
                               + '", expense_name="' + expense_name
                               + '", expense_sum="' + expense_sum
                               + '", expense_currency="' + expense_currency
                               + '", expense_info="' + expense_info
                               + '", expense_payer="' + expense_payer
                               + '", expense_members="' + expense_members
                               + '" WHERE id_unixtime_created=' + id_unixtime_created + ';');
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    return res;
}

function deleteExpense(projectId, entryId) {
    DB.simpleQuery('DELETE FROM expenses WHERE project = ? AND rowid = ?;',
                   [projectId, entryId])
}

function deleteAllExpenses (project_id_timestamp) {
    var db = DB.getDatabase();
    var res = "";
    db.transaction(function(tx) {
        tx.executeSql('CREATE TABLE IF NOT EXISTS table_' + project_id_timestamp + ' (id_unixtime_created TEXT, \
                                                                            date_time TEXT, \
                                                                            expense_name TEXT, \
                                                                            expense_sum TEXT, \
                                                                            expense_currency TEXT, \
                                                                            expense_info TEXT, \
                                                                            expense_payer TEXT, \
                                                                            expense_members TEXT)' );
        var rs = tx.executeSql('DELETE FROM table_' + project_id_timestamp + ';');
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    return res;
}

function getAllExpenses( project_name_table, default_value ) {
    var db = DB.getDatabase();
    var res=[];
    try {
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT * FROM table_'+ project_name_table + ';');
            if (rs.rows.length > 0) {
                for (var i = 0; i < rs.rows.length; i++) {
                    res.push([rs.rows.item(i).id_unixtime_created,
                              rs.rows.item(i).date_time,
                              rs.rows.item(i).expense_name,
                              rs.rows.item(i).expense_sum,
                              rs.rows.item(i).expense_currency,
                              rs.rows.item(i).expense_info,
                              rs.rows.item(i).expense_payer,
                              rs.rows.item(i).expense_members,
                             ])
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
