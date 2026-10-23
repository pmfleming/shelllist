import QtQuick
import QtTest
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity
import Shelllist.Battery as Battery
import Shelllist.Bluetooth as Bluetooth
import Shelllist.Wifi as Wifi

TestCase {
    id: tests
    name: "PresentationData"
    when: windowShown
    visible: true
    width: 650
    height: 450
    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../../contracts/" + name + "-api-ui-contract.fixture.json"), false);
        request.send(); return JSON.parse(request.responseText);
    }
    function test_staticAssetMapsDoNotInferUnknownMetadata() {
        compare(Ui.MaterialIcons.name("constructor"), "");
        compare(Ui.MaterialIcons.name("󰖩"), "wifi");
        compare(Wifi.WifiIcons.forNetwork({security_class:"enterprise"}, false), Wifi.WifiIcons.icons.enterprise);
        compare(Wifi.WifiIcons.forNetwork({security:"WPA ENTERPRISE",wpa_flags:512}, false), Wifi.WifiIcons.icons.unknown);
        compare(Wifi.WifiIcons.forNetwork({security_class:"constructor"}, true), Wifi.WifiIcons.icons["captive-portal"]);
        const device = fixture("bt").snapshot.data.snapshot.devices[0];
        compare(Bluetooth.BluetoothGlyphs.forDevice(device), Bluetooth.BluetoothGlyphs.glyphs[device.icon_id]);
        compare(Bluetooth.BluetoothGlyphs.forDevice({device_type:"Headset",icon:"audio-headset"}), Bluetooth.BluetoothGlyphs.glyphs.bluetooth);
        compare(Bluetooth.BluetoothGlyphs.forDevice({icon_id:"constructor"}), Bluetooth.BluetoothGlyphs.glyphs.bluetooth);
        compare(Battery.BatteryPresentation.lookup(Battery.BatteryPresentation.stateLabels,"charge-paused","missing"),"Charging paused at limit");
        compare(Battery.BatteryPresentation.lookup(Battery.BatteryPresentation.stateLabels,"constructor","missing"),"missing");
        compare(Activity.WeatherVisuals.iconName(0,false),"clear-night");
        compare(Activity.WeatherVisuals.iconName(61,false),"rain");
        for (const code of [null,"0",false,999,-1]) compare(Activity.WeatherVisuals.iconName(code,true),"not-available");
    }
    function test_batteryRendersNativeDurationAndUnitsAndKeepsUnknownUnknown() {
        const battery=fixture("bar").snapshot.battery;
        verify(battery.forecast.duration_label.length > 0);
        const factory=Qt.createComponent(Qt.resolvedUrl("../../qml/Shelllist/Battery/BatteryHistoryCard.qml"));
        compare(factory.status,Component.Ready,factory.errorString());
        const card=createTemporaryObject(factory,tests,{history:{},battery:battery});
        verify(card!==null);
        const power=findChild(card,"batteryHistoryPower");
        const estimate=findChild(card,"batteryForecastTarget");
        compare(power.text,battery.display.power);
        verify(estimate.text.includes(battery.forecast.duration_label));
        const next=JSON.parse(JSON.stringify(battery));
        next.power_watts=1234;
        next.forecast.seconds=17;
        card.battery=next;
        compare(power.text,battery.display.power);
        verify(estimate.text.includes(battery.forecast.duration_label),"changing raw seconds does not invoke a frontend formatter");
        delete next.display;
        card.battery=JSON.parse(JSON.stringify(next));
        compare(power.text,"— W");
    }
    function test_weatherRendersNativeLabelsWithoutRecalculatingRawValues() {
        const source = fixture("bar").snapshot.activity.weather;
        verify(source.display.temperature.length > 0);
        const factory = Qt.createComponent(Qt.resolvedUrl("../../qml/Shelllist/Activity/WeatherHero.qml"));
        compare(factory.status,Component.Ready,factory.errorString());
        const hero = createTemporaryObject(factory,tests,{width:650,weather:source,active:false,updating:false});
        verify(hero !== null);
        const temperature = findChild(hero,"weatherCurrentTemperature");
        compare(temperature.text,source.display.temperature);
        const changed=JSON.parse(JSON.stringify(source));
        changed.temperature_c=999;
        hero.weather=changed;
        compare(temperature.text,source.display.temperature,"raw numeric changes do not run another formatter");
        changed.display.temperature="Native replacement";
        hero.weather=JSON.parse(JSON.stringify(changed));
        compare(temperature.text,"Native replacement");
        delete changed.display;
        hero.weather=changed;
        compare(temperature.text,"—","missing native projection stays unknown");
    }
}
