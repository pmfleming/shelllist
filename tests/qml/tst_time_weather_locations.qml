import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "TimeWeatherLocations"
    when: windowShown
    visible: true
    width: 1100
    height: 700
    Component { id: ownerFactory; Activity.TimeWeatherController {} }
    Component { id: contentFactory; Activity.TimeWeatherContent {} }
    property var views: []
    property int originalScheme: Ui.Theme.previewColorScheme
    function init() { calls = []; views = []; width = 1100; originalScheme = Ui.Theme.previewColorScheme; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function cleanup() { for (const view of views) view.destroy(); wait(0); views = []; Ui.Theme.previewColorScheme = originalScheme; }
    function capture(view, name) {
        const directory=Quickshell.env("SHELLLIST_TIME_REVIEW_DIR") || "";
        if (!directory) return;
        wait(100);verify(waitForPolish(view.Window.window));
        let saved=false;
        verify(view.grabToImage(function(image) {saved=image.saveToFile(directory+name+".png");}));
        tryVerify(()=>saved);
    }
    function place(name, zone) {
        const coords=zone==="Asia/Tokyo" ? [35.6762,139.6503] : zone==="Europe/Dublin" ? [53.3498,-6.2603] : [52.3676,4.9041];
        return {name:name,country:"",region:"",timezone:zone,latitude:coords[0],longitude:coords[1]};
    }
    function city(id, name, home, current) {
        const p=place(current && name==="Current location" ? "Dublin" : name,home?"Europe/Amsterdam":name==="Tokyo"?"Asia/Tokyo":"Europe/Dublin");
        return {id:id,label:name,city:p.name,home:home,current:current,removable:!home&&!current,
            timezone:p.timezone,utc_offset_seconds:home?7200:name==="Tokyo"?32400:3600,abbreviation:home?"CEST":name==="Tokyo"?"JST":"IST",
            clock_display:{time:"12:34",date:"Native date",offset:"Native offset"},
            has_coordinates:true,latitude:p.latitude,longitude:p.longitude,has_weather:false,place:p};
    }
    function rows(atHome) {
        const values=[city("weather:home","Amsterdam",true,false),city("city:1","Tokyo",false,false)];
        if (!atHome) values.push(city("current-location","Current location",false,true));
        return values;
    }
    function control(manual, revision) {return {available:true,manual:manual,revision:revision,paused:false,uncertain:false};}
    function start(atHome, screenWidth) {
        const owner=createTemporaryObject(ownerFactory,testCase,{uiActive:true,availableScreenWidth:screenWidth || 1280});
        width=owner.openWindowWidth;
        owner.activity=Object.assign({},owner.activity,{available:true,location_catalog:{revision:1,writable:true},locations:rows(!!atHome)});
        owner.timezone=Object.assign({},owner.timezone,{location_control:control(true,1)});
        const view=createTemporaryObject(contentFactory,testCase,{controller:owner,width:width,height:height});
        verify(view!==null);
        views = views.concat([view]);
        tryCompare(owner.cityModel,"count",atHome?2:3);
        view.listItem.focusList();
        return {owner:owner,view:view,locations:owner.locations};
    }
    function openDetails(s) {s.view.listItem.focusList();keyClick(Qt.Key_Right);tryCompare(s.owner,"detailsExpansionProgress",1);tryVerify(()=>s.view.detailsNavigation.contentReady);}
    function select(s,id) {s.owner.selectionModel.selectedIndex=s.owner.filteredCities.findIndex(c=>c.id===id);}
    function mutations() {return calls.filter(c=>["locations.add","locations.remove","location.setManual","location.returnToAutomatic"].includes(c.method));}
    function reply(s,id,data) {s.locations.finish(id,{protocol:"bar-api",version:2,ok:true,data:data},"");}
    function test_addedCitySelectionWaitsForCurrentState_data() {
        return [{tag:"select-confirmed",intervene:false},{tag:"preserve-navigation",intervene:true}];
    }
    function test_addedCitySelectionWaitsForCurrentState(data) {
        const s=start(true);
        s.locations.openPicker("add");
        s.locations.candidates=[place("Dublin","Europe/Dublin")];
        s.locations.choice="0";
        s.locations.submitPicker();
        verify(s.locations.mutationId.length>0);
        const activity=Object.assign({},s.owner.activity,{location_catalog:{revision:2,writable:true},locations:rows(true).concat([city("city:2","Dublin",false,false)])});
        reply(s,s.locations.mutationId,{id:"city:2",activity:activity});
        compare(s.owner.cityModel.count,2,"receipt is not the current activity projection");
        if (data.intervene) s.owner.navigationInteracted();
        s.owner.activity=activity;
        tryCompare(s.owner.cityModel,"count",3);
        tryVerify(()=>s.owner.selectedCity.id===(data.intervene?"weather:home":"city:2"));
        compare(mutations().length,1);
    }
    function test_nativeClockUpdatesKeepTheCityDelegateAndOpenDraft() {
        const s=start(false);openDetails(s);
        const row=findChild(s.view,"timeWeatherLocation::weather:home");
        verify(row!==null);
        const clock=findChild(s.view,"locationClockTime");
        compare(clock.text,"12:34");
        s.view.listItem.focusList();keyClick(Qt.Key_L,Qt.AltModifier);
        tryCompare(s.locations,"pickerMode","manual");
        const query=s.locations.query;
        wait(200); // Let any picker-opening read settle before observing the clock update.
        const requestCount=calls.length;
        const updated=JSON.parse(JSON.stringify(s.owner.activity));
        updated.locations[0].clock_display={time:"12:35",date:"Next native date",offset:"Native offset"};
        s.owner.activity=updated;
        tryCompare(clock,"text","12:35");
        compare(findChild(s.view,"timeWeatherLocation::weather:home"),row,"native clock changes use shared keyed updates, never recreate the row");
        compare(s.owner.selectedCity.id,"weather:home");
        compare(s.locations.pickerMode,"manual");
        compare(s.locations.query,query);
        compare(calls.length,requestCount,"clock publication does not request another read or mutation");
        compare(mutations().length,0);
        keyClick(Qt.Key_Escape);
        tryCompare(s.locations,"pickerMode","");
    }
    function test_manualPrimaryAcknowledgementAndNoDuplicateSubmit() {
        const s=start(false);openDetails(s);
        mouseClick(findChild(s.view,"detailAction:manual"));tryCompare(s.locations,"pickerMode","manual");
        verify(s.locations.validPlace(s.locations.selectedPlace));compare(mutations().length,0);
        capture(s.view,"manual-picker");
        mouseClick(findChild(findChild(s.view,"timeWeatherCityPicker"),"detailAction:accept"));
        tryVerify(()=>s.locations.busy);compare(mutations().length,1);
        s.locations.submitPicker();compare(mutations().length,1);
        const request=mutations()[0];compare(request.method,"location.setManual");
        compare(request.params.place.name,"Amsterdam");verify(s.locations.modalOpen,"admission is not acknowledgement");
        reply(s,s.locations.mutationId,{location_control:Object.assign(control(true,2),{operation_id:request.params.request_id,operation_status:"applied"})});
        compare(s.locations.pickerMode,"");compare(s.locations.controlState.revision,2);
    }
    function test_removeConfirmationCapturesIdentityAndAutomaticAtHome() {
        const s=start(true);openDetails(s);
        verify(!findChild(s.view,"detailAction:remove").enabled);
        keyClick(Qt.Key_R,Qt.AltModifier);tryCompare(s.locations,"mutationKind","automatic");
        const auto=mutations()[0];compare(auto.method,"location.returnToAutomatic");
        reply(s,s.locations.mutationId,{location_control:Object.assign(control(false,2),{operation_id:auto.params.request_id,operation_status:"applied"})});
        verify(!s.locations.canAutomatic);
        select(s,"city:1");s.view.listItem.focusList();keyClick(Qt.Key_D,Qt.AltModifier);
        tryVerify(()=>s.locations.removal!==null);
        const modal=findChild(s.view,"timeWeatherRemoveConfirmation");
        tryVerify(()=>findChild(modal,"detailAction:reject").activeFocus);
        keyClick(Qt.Key_Escape);compare(s.locations.removal,null);compare(mutations().length,1);
        s.view.listItem.focusList();keyClick(Qt.Key_D,Qt.AltModifier);tryVerify(()=>s.locations.removal!==null);
        mouseClick(findChild(modal,"detailAction:accept"));
        compare(mutations().length,2);compare(mutations()[1].params.id,"city:1");
        verify(s.owner.cities.some(c=>c.id==="city:1"),"no optimistic removal");
        const activity=Object.assign({},s.owner.activity,{location_catalog:{revision:2,writable:true},locations:rows(true).filter(c=>c.id!=="city:1")});
        reply(s,s.locations.mutationId,{id:"city:1",activity:activity});
        compare(s.owner.cityModel.count,2,"city receipt does not overwrite the ordered activity projection");
        s.owner.activity=activity; // Independently reconciled live state, not the receipt.
        tryCompare(s.owner.cityModel,"count",1);compare(s.owner.selectedCity.id,"weather:home");
    }
}
