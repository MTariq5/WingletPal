import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LocationProvider 1.0
import CitySearch 1.0

Popup {
    id: root
    required property LocationProvider locationProvider
    property string saveError: ""
    modal: true
    focus: true
    padding: 10
    onOpened: {
        cityQuery.text = ""
        saveError = ""
        citySearch.clear()
    }
    onAboutToHide: {
        searchDelay.stop()
        citySearch.clear()
    }
    function searchCities() {
        root.saveError = ""
        searchDelay.stop()
        if (cityQuery.text.trim().length >= 2)
            citySearch.search(cityQuery.text)
    }
    Timer {
        id: searchDelay
        interval: 350
        onTriggered: root.searchCities()
    }
    CitySearch { id: citySearch }
    background: Rectangle { color: "#191919"; border.color: "#D9A441" }
    contentItem: ColumnLayout {
        spacing: 3
        RowLayout {
            Text { text: qsTr("Choose city"); color: "#D9A441"; Layout.fillWidth: true }
            Button { text: qsTr("Back"); Layout.preferredHeight: 30; onClicked: root.close() }
        }
        TextField {
            id: cityQuery
            placeholderText: qsTr("City name (Arabic or English)…")
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            onAccepted: root.searchCities()
            onTextEdited: {
                searchDelay.stop()
                citySearch.clear()
                root.saveError = ""
                if (text.trim().length >= 2) searchDelay.restart()
            }
        }
        Text {
            text: qsTr("Saved: %1").arg(root.locationProvider.city)
            color: "#BBBBBB"
            font.pixelSize: 11
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        ListView {
            id: cityList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: citySearch.results
            ScrollBar.vertical: ScrollBar {}
            delegate: Button {
                required property var modelData
                width: cityList.width
                height: 44
                contentItem: Column {
                    Text { width: parent.width; text: modelData.name; font.pixelSize: 13; elide: Text.ElideRight; color: "white" }
                    Text {
                        width: parent.width
                        text: [modelData.region, modelData.country].filter(function(part) { return part.length > 0 }).join(" · ")
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        color: "#CCCCCC"
                    }
                }
                background: Rectangle { color: parent.down ? "#514322" : "#303030"; radius: 4 }
                onClicked: {
                    if (root.locationProvider.saveManualLocation(modelData.name, modelData.latitude, modelData.longitude))
                        root.close()
                    else root.saveError = root.locationProvider.error
                }
            }
            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: citySearch.error || root.saveError ? "#FF8888" : "#CCCCCC"
                visible: citySearch.results.length === 0 || root.saveError.length > 0
                text: root.saveError || citySearch.error || (citySearch.searching || searchDelay.running ? qsTr("Searching…")
                      : citySearch.searched ? qsTr("No cities found. Try another spelling or English.")
                      : qsTr("Type at least two characters, then tap a city to save it."))
            }
        }
        Text {
            text: "Open-Meteo / GeoNames"
            color: "#999999"
            font.pixelSize: 9
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
