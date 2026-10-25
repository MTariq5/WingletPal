import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

// Shown instead of the main SwipeView UI (see main.qml's appState) whenever
// ConnectivityChecker reports no internet at startup. Lets the user pick a
// nearby Wi-Fi network, enter its password, and join it — then re-runs
// connectivityChecker so main.qml can move on to the real UI once there's
// actually internet (not just an associated Wi-Fi link; the two aren't the
// same thing, which is the whole reason ConnectivityChecker exists rather
// than trusting the OS's own "connected" flag).
//
// `wifiManager`/`connectivityChecker` are handed down as plain references
// from main.qml — the same "reuse the existing single instance" pattern
// every other page in this app already uses for location/weather/timeDate.
// This page owns no networking of its own; it only ever calls methods on
// the instances it's given.
//
// Text entry uses the system physical keyboard.
Item {
    id: root

    property var wifiManager: null
    property var connectivityChecker: null

    // Which network (if any) the password step below is showing for. null
    // means the list step is showing instead.
    property var selectedNetwork: null

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    // A plain Rectangle has no input handling and doesn't consume clicks —
    // without this, tapping empty space on this page (anywhere not already
    // covered by a Button/list-item MouseArea below) would fall straight
    // through to mainRec's SwipeView underneath, defeating the whole point
    // of this page blocking the app while offline. Declared before the
    // real controls further down so they still paint on top and keep
    // handling their own clicks first; this only catches whatever they
    // don't.
    MouseArea {
        anchors.fill: parent
    }

    // Kicks off an initial scan the moment this page actually appears
    // (rather than on Component.onCompleted, which would fire even while
    // this Item exists but isn't the visible one) — matches
    // FlightTrackerProvider's own "refresh immediately on becoming visible"
    // behavior in spirit, just via visibleChanged instead of an
    // active/SwipeView.isCurrentItem property, since this page isn't a
    // SwipeView child.
    onVisibleChanged: {
        if (root.visible && root.wifiManager)
            root.wifiManager.scanNetworks()
    }

    // ── Step 1: network list ────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: root.selectedNetwork === null

        Column {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 2

            Text {
                text: "No Internet Connection"
                color: "white"
                font.bold: true
                font.pixelSize: 18
            }
            Text {
                text: "Select a Wi-Fi network to continue"
                color: "#AAAAAA"
                font.pixelSize: 12
            }
        }

        ListView {
            id: networkList
            anchors.top: header.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.bottomMargin: 8
            anchors.margins: 10
            clip: true
            spacing: 4
            model: root.wifiManager ? root.wifiManager.networks : []

            delegate: Rectangle {
                width: networkList.width
                height: 34
                radius: 6
                color: "#1E1E1E"

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.secured ? "🔒" : "📶"
                        font.pixelSize: 13
                        color: "white"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 70
                        text: modelData.ssid
                        color: "white"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.signal + "%"
                        color: "#AAAAAA"
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectedNetwork = modelData
                }
            }

            Text {
                anchors.centerIn: parent
                visible: networkList.count === 0
                color: "#AAAAAA"
                font.pixelSize: 12
                text: root.wifiManager && root.wifiManager.scanning ? "Scanning…" : "No networks found"
            }
        }

        Row {
            id: footer
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 8
            spacing: 12

            Button {
                id: rescanBtnID
                width: 110
                height: 65

                background: Rectangle {
                    radius: 6

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#48515a" }
                        GradientStop { position: 1.0; color: "#02050c" }
                    }

                    border.color: rescanBtnID.hovered ? "#3498DB" : "transparent"
                    border.width: 2
                }

                //text: "Rescan"
                Text {
                    text: "Rescan"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width

                    anchors.verticalCenter: parent.verticalCenter
                }

                enabled: root.wifiManager && !root.wifiManager.scanning && !root.wifiManager.connecting
                onClicked: root.wifiManager.scanNetworks()
            }

            Button {
                id: retryBtnID
                width: 110
                height: 65

                background: Rectangle {
                    radius: 6

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#48515a" }
                        GradientStop { position: 1.0; color: "#02050c" }
                    }

                    border.color: retryBtnID.hovered ? "#3498DB" : "transparent"
                    border.width: 2
                }

                //text: "Retry"
                Text {
                    text: "Retry"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width

                    anchors.verticalCenter: parent.verticalCenter
                }

                // Re-checks connectivity directly, without touching Wi-Fi
                // at all — covers the case where the user already fixed
                // their connection some other way (OS settings, a router
                // reboot) and just needs main.qml's gate to notice.
                onClicked: if (root.connectivityChecker) root.connectivityChecker.checkNow()
            }
        }
    }

    // ── Step 2: password entry ──────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: root.selectedNetwork !== null

        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 10

            Text {
                width: parent.width
                text: root.selectedNetwork ? root.selectedNetwork.ssid : ""
                color: "white"
                font.bold: true
                font.pixelSize: 14
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            TextField {
                id: passwordField
                width: parent.width
                height: 60
                visible: root.selectedNetwork && root.selectedNetwork.secured
                placeholderText: "Password"
                echoMode: TextInput.Password
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: root.wifiManager && root.wifiManager.status === "Failed" ? "#FF6B6B" : "#AAAAAA"
                font.pixelSize: 10
                text: {
                    if (!root.wifiManager) return ""
                    if (root.wifiManager.connecting) return "Connecting…"
                    if (root.wifiManager.status === "Failed")
                        return root.wifiManager.errorString !== "" ? root.wifiManager.errorString : "Connection failed"
                    return ""
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Button {
                    id:cancelBtnID

                    width: 110
                    height: 65

                    background: Rectangle {
                        radius: 6

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#48515a" }
                            GradientStop { position: 1.0; color: "#02050c" }
                        }

                        border.color: cancelBtnID.hovered ? "#3498DB" : "transparent"
                        border.width: 2
                    }

                    //text: "Cancel"
                    Text {
                        text: "Cancel"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    enabled: root.wifiManager && !root.wifiManager.connecting
                    onClicked: {
                        passwordField.text = ""
                        root.selectedNetwork = null
                    }
                }

                Button {
                    id:connectBtnID

                    width: 110
                    height: 65

                    background: Rectangle {
                        radius: 6

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#48515a" }
                            GradientStop { position: 1.0; color: "#02050c" }
                        }

                        border.color: connectBtnID.hovered ? "#3498DB" : "transparent"
                        border.width: 2
                    }

                    //text: "Connect"
                    Text {
                        text: "Connect"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    enabled: root.wifiManager && !root.wifiManager.connecting
                    onClicked: {
                        if (!root.wifiManager || !root.selectedNetwork)
                            return
                        root.wifiManager.connectToNetwork(
                            root.selectedNetwork.ssid,
                            root.selectedNetwork.secured ? passwordField.text : ""
                        )
                    }
                }
            }
        }
    }

    Connections {
        target: root.wifiManager
        function onConnectionResult(success, error) {
            if (success) {
                passwordField.text = ""
                root.selectedNetwork = null
                if (root.connectivityChecker)
                    root.connectivityChecker.checkNow()
            }
            // On failure, deliberately stay on the password step — the
            // status/errorString-driven Text above already surfaces the
            // reason, and the Connect/Cancel buttons re-enable themselves
            // via wifiManager.connecting going back to false.
        }
    }
}
