/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

#include <QtQuick>
#include <QFileInfo>
#include <sailfishapp.h>
#include "requires_defines.h"
#include "quiet_logging.h"

void migrateDatabase() {
    const auto path = QStringLiteral("QML/OfflineStorage/Databases/");
    const auto ini = QStringLiteral(".ini");
    const auto db = QStringLiteral(".sqlite");
    const auto oldBasename = QStringLiteral("4571a28a53ace9fa74e99ab9f5e19409");
    const auto newBasename = QStringLiteral("fad58de7366495db4650cfefac2fcd61");

    auto newIni = QStandardPaths::locate(QStandardPaths::StandardLocation::AppDataLocation,
                                         path + newBasename + ini);

    if (newIni.isEmpty()) { // new ini is missing
        auto oldDb = QStandardPaths::locate(QStandardPaths::StandardLocation::AppDataLocation,
                                            path + oldBasename + db);

        if (!oldDb.isEmpty()) { // old db exists
            auto baseDir = QFileInfo(oldDb).absolutePath() + "/";
            auto oldIni = baseDir + oldBasename + ini;
            auto newDb = baseDir + newBasename + db;
            newIni = baseDir + newBasename + ini;

            if (QFileInfo::exists(oldIni) && !QFileInfo::exists(newDb)) {
                qDebug() << "migrating database to new location:" << oldDb << "to" << newDb;

                QSettings oldIniSettings(oldIni, QSettings::IniFormat);
                auto oldVersion = oldIniSettings.value("Version", "").toString();

                QFile newIniFile(newIni);

                if (!newIniFile.open(QIODevice::ReadWrite | QIODevice::Text)) {
                    qCritical() << "database migration failed: cannot open new database ini file at" << newIni;
                    return;
                } else {
                    auto data = QString(R"([General]
Description=Main Expenditure database
Driver=QSQLITE
EstimatedSize=2000000
Name=main
Version=%1
)").arg(oldVersion).toStdString();
                    newIniFile.write(data.c_str());
                    newIniFile.close();

                    QFile::rename(oldDb, newDb);
                    QFile::remove(oldIni);
                }
            }
        }
    }
}

int main(int argc, char *argv[])
{
    setupLogging();

    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName("org.tplabs"); // needed for Sailjail
    app->setApplicationName("expenditure");

    migrateDatabase();

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty("APP_VERSION", QString(APP_VERSION));
    view->rootContext()->setContextProperty("APP_RELEASE", QString(APP_RELEASE));

    view->engine()->addImportPath(SailfishApp::pathTo("qml/modules").toString());
    view->setSource(SailfishApp::pathToMainQml());
    view->show();
    return app->exec();
}
