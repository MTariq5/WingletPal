import QtQuick 2.9

import "../Utilities"


Rectangle{
    id:g5BattRoot
    border.color: "gray"
    border.width: 1
    color: "black"

    property real battVal: 100
    property bool chargingHardwareFault: false
    property bool charging: true

    property bool batt_fault: false
    property bool noBatt: false


    onBattValChanged: update();


    function update(){
        if( 100 >= battVal && battVal >= 80){
            percentage_100.visible = true;
            percentage_75.visible = true;
            percentage_50.visible = true;
            percentage_25.visible = true;

            percentage_50.color = "green"
            percentage_25.color = "green"
            battFrame.source = "qrc:/Resources/G5/Battery/battery.svg"
        }
        else if( 80 > battVal && battVal >= 60 ){
            percentage_100.visible = false;
            percentage_75.visible = true;
            percentage_50.visible = true;
            percentage_25.visible = true;

            percentage_50.color = "green"
            percentage_25.color = "green"
            battFrame.source = "qrc:/Resources/G5/Battery/battery.svg"
        }
        else if( 60 > battVal && battVal >= 40 ){
            percentage_100.visible = false;
            percentage_75.visible = false;
            percentage_50.visible = true;
            percentage_25.visible = true;

            percentage_50.color = "yellow"
            percentage_25.color = "yellow"
            battFrame.source = "qrc:/Resources/G5/Battery/Low_battery.svg"

        }
        else if( 40 > battVal && battVal >= 20 ){
            percentage_100.visible = false;
            percentage_75.visible = false;
            percentage_50.visible = false;
            percentage_25.visible = true;

            percentage_25.color = "red"
            battFrame.source = "qrc:/Resources/G5/Battery/Zero_battery.svg"
        }
        else if( 20 > battVal && battVal >= 0 ){
            percentage_100.visible = false;
            percentage_75.visible = false;
            percentage_50.visible = false;
            percentage_25.visible = false;
        }
    }



    Image{
        id:battFrame
        source: "qrc:/Resources/G5/Battery/battery.svg"
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 2
        sourceSize.width: parent.width * 0.45
        sourceSize.height : parent.height * 0.5

        //1 from left
        Rectangle{
            id:percentage_25
            width: parent.width /4 -4
            height: parent.height - 6
            anchors.verticalCenter: parent.verticalCenter
            color: "green"
            anchors.left: parent.left
            anchors.leftMargin: 2
        }

        //2 from left
        Rectangle{
            id:percentage_50
            width:  parent.width /4 -4
            height: parent.height - 6
            anchors.verticalCenter: parent.verticalCenter
            color: "green"
            anchors.left: percentage_25.right
            anchors.leftMargin:2
        }

        //3 from left
        Rectangle{
            id:percentage_75
            width:  parent.width /4 -4
            height: parent.height - 6
            anchors.verticalCenter: parent.verticalCenter
            color: "green"
            anchors.left: percentage_50.right
            anchors.leftMargin: 2
        }

        //4 from left
        Rectangle{
            id:percentage_100
            width:  parent.width /4 -4
            height: parent.height - 6
            anchors.verticalCenter: parent.verticalCenter
            color: "green"
            anchors.left: percentage_75.right
            anchors.leftMargin: 2
        }

        //CHARGING
        CustomImage{
            visible: charging
            source: "qrc:/Resources/G5/Battery/charging.svg"
            anchors.centerIn: parent

            sourceSize.width: parent.width * 0.45
            sourceSize.height: parent.height * 0.6
        }

        //CHARGING Hardware Fault
        CustomImage{
            visible: chargingHardwareFault
            source: "qrc:/Resources/G5/Battery/charging_hardware_fault.svg"
            anchors.centerIn: parent
        }

    }


    //BATTERY VAL RECTANGLE
    Rectangle{
        width: parent.width - battFrame.width
        height: parent.height
        color: "transparent"

        //BATTERY VALUE
        Text {
            id: batt_percentage
            text: battVal.toFixed(0) + "%"
            font.bold: true
            font.pixelSize: g5BattRoot.width * 0.16
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }
    }


    //NO BATTERY
    CustomImage{
        anchors.fill: parent
        visible: noBatt
        source: "qrc:/Resources/G5/Battery/No_Batt.svg"
        anchors.centerIn: parent
    }


    //BATTERY FAULT
    CustomImage{
        anchors.fill: parent
        visible: batt_fault
        source: "qrc:/Resources/G5/Battery/Batt_fail.svg"
        anchors.centerIn: parent
    }

}
