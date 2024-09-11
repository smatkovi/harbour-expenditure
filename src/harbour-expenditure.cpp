/*
 * This file is part of harbour-expenditure.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Tobias Planitzer
 * SPDX-FileCopyrightText: 2023-2024 Mirian Margiani
 */

#include <QtQuick>
#include <QDebug>
#include <sailfishapp.h>
#include "requires_defines.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName("org.tplabs"); // needed for Sailjail
    app->setApplicationName("expenditure");

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty("APP_VERSION", QString(APP_VERSION));
    view->rootContext()->setContextProperty("APP_RELEASE", QString(APP_RELEASE));

    view->engine()->addImportPath(SailfishApp::pathTo("qml/modules").toString());
    view->setSource(SailfishApp::pathToMainQml());
    view->show();
    return app->exec();
}
