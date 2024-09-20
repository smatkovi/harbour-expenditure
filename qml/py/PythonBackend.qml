import QtQuick 2.6
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

Python {
    id: root

    Component.onCompleted: {
        addImportPath(Qt.resolvedUrl('../py'))
    }

    onReceived: {
        Notices.show(data); console.log(data)
    }

    onError: {
        console.error("an error occurred in the Python backend, traceback:")
        console.error(traceback)

        Notices.show("\n" + qsTr("An error occurred in the Python backend.\n" +
                                 "Please restart the app and check the logs.") +
                     "\n", 10000, Notice.Center)
    }
}
