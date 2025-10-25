/*
 * Splitwise Sync Component
 * Handles bidirectional sync between Expenditure and Splitwise
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

Item {
    id: root
    
    // Configure your Splitwise group ID here
    property int groupId: 0  // SET YOUR GROUP ID HERE
    
    property bool syncing: false
    property string statusMessage: ""
    
    signal syncCompleted(bool success, string message)
    signal syncProgress(string message)
    
    Python {
        id: py
        
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../py'))
            
            importModule('splitwise_backend', function() {
                console.log("Splitwise backend loaded successfully")
            })
        }
        
        onError: {
            console.log("Python error: " + traceback)
            root.syncing = false
            root.syncCompleted(false, "Error: " + traceback)
        }
        
        onReceived: {
            console.log("Python message: " + data)
        }
    }
    
    function startSync() {
        if (syncing) {
            console.log("Sync already in progress")
            return
        }
        
        if (groupId === 0) {
            syncCompleted(false, "Please configure groupId in SplitwiseSync.qml")
            return
        }
        
        syncing = true
        statusMessage = "Syncing with Splitwise..."
        syncProgress(statusMessage)
        
        // Pass null to let Python backend find the active project
        py.call('splitwise_backend.sync_project', [null, groupId], function(result) {
            syncing = false
            
            if (result.success) {
                statusMessage = result.message
                syncCompleted(true, result.message)
            } else {
                statusMessage = result.error || "Unknown error"
                syncCompleted(false, statusMessage)
            }
        })
    }
}
