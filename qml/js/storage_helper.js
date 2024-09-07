/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Mirian Margiani
 */

.pragma library
.import QtQuick.LocalStorage 2.0 as LS

//
// BEGIN Database configuration
//

var dbName = "MyDatabase"
var dbDescription = ""
var dbSize = 2000000  // 2 MB
var enableAutoMaintenance = true

var dbMigrations = [
    // [0.1, 'CREATE TABLE IF NOT EXISTS ...;'],
    // [0.2, function(tx){ tx.executeSql(...); }],

    // add new versions here...
    //
    // remember: versions must be numeric, e.g. 0.1 but not 0.1.1
]


//
// BEGIN Database handling boilerplate
// It is usually not necessary to change this part.
//
// Functions:
// - simpleQuery(query, values): for most queries.
// - readQuery(query, values): for read-only queries.
// - getDatabase(): to get full access to the database.
//
// - defaultFor(arg, val): to use a fallback value 'val' if 'arg' is nullish.
// - getSetting(key, fallback): get a settings value from the settings table.
// - setSetting(key, value): save a settings value to the settings table.
//
// Properties:
// - dbOk: set to false if the database is unavailable due to errors.

var dbOk = true

var _keyValueSettingsTable = "__local_settings"

var __initialized = false
var __db = null

function defaultFor(arg, val) {
    return typeof arg !== 'undefined' ? arg : val
}

function getDatabase() {
    if (!dbOk) {
        console.error("database is not available, check previous logs")
        throw "database is not available, check previous logs";
    }

    if (!__initialized || __db === null) {
        console.log("initializing database...")

        // 5 MB estimated size
        __db = LS.LocalStorage.openDatabaseSync(
            dbName, "", dbDescription, dbSize);

        if (__doInit(__db)) {
            __initialized = true;
            dbOk = true;

            if (enableAutoMaintenance) {
                __doDatabaseMaintenance();
            }
        } else {
            dbOk = false;
        }
    }

    return __db;
}

function readQuery(query, values) {
    return simpleQuery(query, values, true)
}

function simpleQuery(query, values, readOnly) {
    var db = getDatabase();
    var res = {
        ok: false,
        rowsAffected: 0,
        rows: []
    };

    values = defaultFor(values, []);

    if (!query) {
        console.error("bug: cannot execute an empty database query");
        return res;
    }

    try {
        var callback = function(tx) {
            var rs = tx.executeSql(query, values);

            if (rs.rowsAffected > 0) {
                res.rowsAffected = rs.rowsAffected;
            } else {
                res.rowsAffected = 0;
            }

            res.rows = rs.rows;
        };

        if (readOnly === true) {
            db.readTransaction(callback)
        } else {
            db.transaction(callback)
        }

        res.ok = true;
    } catch(e) {
        console.error("database query failed:\n", e, "\nquery values:", values);
        res.ok = false;
    }

    return res;
}

function setSetting(key, value) {
    simpleQuery('INSERT OR REPLACE INTO %1 VALUES (?, ?);'.arg(_keyValueSettingsTable),
                [key, value]);
}

function getSetting(key, fallback) {
    var res = simpleQuery('SELECT value FROM %1 WHERE key=? LIMIT 1;'.
                            arg(_keyValueSettingsTable),
                          [key]);

    if (res.rows.length > 0) {
        res = defaultFor(res.rows.item(0).value, fallback);
    } else {
        res = fallback;
    }

    return res;
}

function _createSettingsTable(tx) {
    tx.executeSql('CREATE TABLE IF NOT EXISTS %1 (key TEXT UNIQUE, value TEXT);'.
                  arg(_keyValueSettingsTable));
}

function __doInit(db) {
    var latestVersion = dbMigrations[dbMigrations.length-1][0]

    var initialVersion = db.version
    var previousVersion = Number(initialVersion)
    var nextVersion = null

    if (initialVersion !== String(latestVersion)) {
        for (var i in dbMigrations) {
            nextVersion = dbMigrations[i][0]

            if (previousVersion < nextVersion) {
                var migrationType = typeof dbMigrations[i][1]

                try {
                    console.log("migrating database to version", nextVersion)

                    if (migrationType === "string") {
                        db.changeVersion(db.version, nextVersion, function(tx) {
                            tx.executeSql(dbMigrations[i][1])
                        })
                    } else if (migrationType === "function") {
                        db.changeVersion(db.version, nextVersion, dbMigrations[i][1])
                    } else {
                        throw "expected migration as string or function, got " +
                                migrationType + " instead"
                    }
                } catch (e) {
                    console.error("fatal: failed to upgrade database version from",
                                  previousVersion, "to", nextVersion)
                    console.error("exception:\n", e)
                    db.changeVersion(db.version, previousVersion, function(tx){})
                    break
                }

                previousVersion = nextVersion
            }
        }
    }

    if (previousVersion !== latestVersion) {
        console.error("fatal: expected database version",
                      String(latestVersion),
                      "but loaded database has version", previousVersion)
        return false
    }

    console.log("loaded database version", db.version)

    db.transaction(_createSettingsTable);

    return true
}

function __vacuumDatabase() {
    var db = getDatabase();

    try {
        db.transaction(function(tx) {
            // VACUUM cannot be executed inside a transaction, but the LocalStorage
            // module cannot execute queries without one. Thus we have to manually
            // end the transaction from inside the transaction...
            var rs = tx.executeSql("END TRANSACTION;");
            var rs2 = tx.executeSql("VACUUM;");
        });
    } catch(e) {
        console.error("database vacuuming failed:\n", e);
    }
}

function __doDatabaseMaintenance() {
    var last_maintenance = simpleQuery(
        'SELECT * FROM %1 WHERE key = "last_maintenance" \
             AND value >= date("now", "-60 day") LIMIT 1;'.
                arg(_keyValueSettingsTable),
        [], true);

    if (last_maintenance.rows.length > 0) {
        return;
    }

    console.log("running regular database maintenance...")
    __vacuumDatabase();
    console.log("maintenance finished")
    setSetting("last_maintenance", new Date().toISOString());
}
