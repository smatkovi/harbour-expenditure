import QtQuick 2.6
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

Python {
    id: root

    function _log(data) {
        console.log("[PY]", data)
    }

    Component.onCompleted: {
        addImportPath(Qt.resolvedUrl('../py'))
        setHandler('log', _log)
    }

    onReceived: {
        console.log(data)
        Notices.show(data)
    }

    onError: {
        console.error("an error occurred in the Python backend, traceback:")
        console.error(traceback)

        Notices.show("\n" + qsTr("An error occurred in the Python backend.\n" +
                                 "Please restart the app and check the logs.") +
                     "\n", 10000, Notice.Center)
    }
}
