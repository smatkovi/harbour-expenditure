/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Mirian Margiani
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 */

.pragma library
.import "storage_helper.js" as DB

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
        return {
            ident: res.rows.item(0).project_id_timestamp,
            name: res.rows.item(0).project_name,
            members: res.rows.item(0).project_members.split(' ||| '),
            lastPayer: res.rows.item(0).project_recent_payer_boolarray,
            lastBeneficiaries: res.rows.item(0).project_recent_beneficiaries_boolarray.split(' ||| '),
            baseCurrency: res.rows.item(0).project_base_currency,
        }
    }

    return null
}

function getProjectEntries(ident) {
    var order = Number(DB.getSetting("sortOrderExpensesIndex", 0)) == Number(0) ?
                'DESC' : 'ASC'

    var res = DB.readQuery('SELECT * FROM table_%1 \
        ORDER BY date_time %2;'.arg(String(ident)).arg(order))
    var entries = []

    var allMembers = DB.readQuery('SELECT project_members FROM \
        projects_table WHERE project_id_timestamp = ? LIMIT 1;',
        [String(ident)])
    allMembers = allMembers.rows.item(0).project_members

    if (res.rows.length === 0) return []

    for (var i = 0; i < res.rows.length; i++) {
        entries.push({
            ident: res.rows.item(i).id_unixtime_created,
            date_time: res.rows.item(i).date_time,
            section_string: new Date(Number(res.rows.item(i).date_time)).toLocaleString(Qt.locale(), 'yyyy-MM-dd'),
            name: res.rows.item(i).expense_name,
            sum: res.rows.item(i).expense_sum,
            currency: res.rows.item(i).expense_currency,
            info: res.rows.item(i).expense_info,
            payer: res.rows.item(i).expense_payer,
            beneficiaries: res.rows.item(i).expense_members.split(' ||| '),
            beneficiaries_string: res.rows.item(i).expense_members === allMembers ?
                qsTr("everyone") : res.rows.item(i).expense_members.split(' ||| ').join(', '),
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

function deleteExpense (project_id_timestamp, id_unixtime_created) {
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
        //var rs = tx.executeSql('DELETE FROM table_' + project_id_timestamp + ';');
        var rs = tx.executeSql('DELETE FROM table_' + project_id_timestamp + ' WHERE id_unixtime_created=' + id_unixtime_created + ';');
        if (rs.rowsAffected > 0) {
            res = "OK";
        } else {
            res = "Error";
        }
    }
    );
    return res;
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
