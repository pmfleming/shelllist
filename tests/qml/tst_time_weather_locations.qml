import QtQuick
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
    function init() { calls = []; views = []; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function cleanup() { for (const view of views) view.destroy(); wait(0); views = []; }
    function place(name, zone) { return {name: name, country: "", region: "", timezone: zone, latitude: 52.3676, longitude: 4.9041}; }
    function city(id, name, home, current) {
        return {id:id,label:name,city:name,home:home,current:current,removable:!home&&!current,
            timezone:home?"Europe/Amsterdam":"Europe/Dublin",utc_offset_seconds:3600,abbreviation:"CET",
            has_coordinates:true,latitude:52.3676,longitude:4.9041,has_weather:false,
            place:place(name,home?"Europe/Amsterdam":"Europe/Dublin")};
    }
    function rows(atHome) {
        const values=[city("weather:home","Amsterdam",true,atHome),city("city:1","Tokyo",false,false)];
        if (!atHome) values.push(city("current-location","Current location",false,true));
        return values;
    }
    function control(manual, revision) {return {available:true,manual:manual,revision:revision,paused:false,uncertain:false};}
    function start(atHome) {
        const owner=createTemporaryObject(ownerFactory,testCase,{uiActive:true});
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
    function test_sameHeaderForEveryCityAndBothTabs_data() {return [{tag:"normal",w:1100},{tag:"minimum",w:976}];}
    function test_sameHeaderForEveryCityAndBothTabs(data) {
        const s=start(false);s.view.width=data.w;openDetails(s);
        let geometry="";
        for (const id of ["weather:home","current-location","city:1"]) {
            select(s,id);
            for (const tab of ["time","weather"]) {
                s.owner.setDetailsTab(tab);
                const primary=findChild(s.view,"detailAction:manual");
                tryVerify(()=>primary!==null && primary.visible);
                const automatic=findChild(s.view,"detailAction:automatic"), remove=findChild(s.view,"detailAction:remove");
                verify(automatic!==null && remove!==null);
                compare(primary.width,56);compare(automatic.width,32);compare(remove.width,32);
                verify(primary.enabled && automatic.enabled);
                compare(remove.enabled,id==="city:1");
                verify(!primary.activeFocusOnTab && !automatic.activeFocusOnTab && !remove.activeFocusOnTab);
                const current=JSON.stringify([primary.x,primary.y,automatic.x,automatic.y,remove.x,remove.y,s.view.detailsItem.headerHeight]);
                if (geometry) compare(current,geometry);else geometry=current;
            }
        }
        compare(mutations().length,0);
    }
    function test_roleIconsArrivalHomeAndDepartureRetainNavigation() {
        const s=start(false);select(s,"current-location");openDetails(s);
        compare(s.owner.selectedCity.id,"current-location");
        const current=findChild(s.view,"timeWeatherLocation::current-location");compare(current.leadingIcon,"my_location");
        compare(findChild(s.view,"timeWeatherLocation::weather:home").leadingIcon,"home");
        s.owner.activity=Object.assign({},s.owner.activity,{locations:rows(true)});
        tryVerify(()=>s.owner.selectedCity.id==="weather:home");
        verify(s.owner.detailsOpen);compare(s.owner.detailsTab,"time");
        const home=findChild(s.view,"timeWeatherLocation::weather:home");
        tryVerify(()=>findChild(home,"timeWeatherHomeCurrentIcon").visible);
        verify(home.accessibleName.includes("Home") && home.accessibleName.includes("Current location"));
        s.owner.activity=Object.assign({},s.owner.activity,{locations:rows(false)});
        tryCompare(s.owner.cityModel,"count",3);compare(s.owner.selectedCity.id,"weather:home");
        compare(mutations().length,0);
    }
    function test_addIconAndShortcutDraftCancelAndStaleSearch() {
        const s=start(false);
        const plus=findChild(s.view,"fieldTrailingAction");verify(plus!==null);mouseClick(plus);
        tryCompare(s.locations,"pickerMode","add");
        const query=findChild(s.view,"searchChoiceQuery");query.focusInput(false);
        keyClick(Qt.Key_D);keyClick(Qt.Key_U);
        compare(mutations().length,0);
        keyClick(Qt.Key_L,Qt.AltModifier);compare(s.locations.pickerMode,"add","underlying manual shortcut blocked");
        s.locations.search();const old=s.locations.searchId;
        keyClick(Qt.Key_Escape);tryCompare(s.locations,"pickerMode","");
        reply(s,old,{places:[place("Dublin","Europe/Dublin")]});compare(s.locations.candidates.length,0);
        s.view.listItem.focusSearch();keyClick(Qt.Key_Return,Qt.AltModifier);tryCompare(s.locations,"pickerMode","add");
        keyClick(Qt.Key_Escape);compare(mutations().length,0);
    }
    function test_manualPrimaryAcknowledgementAndNoDuplicateSubmit() {
        const s=start(false);openDetails(s);
        mouseClick(findChild(s.view,"detailAction:manual"));tryCompare(s.locations,"pickerMode","manual");
        verify(s.locations.validPlace(s.locations.selectedPlace));compare(mutations().length,0);
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
        tryCompare(s.owner.cityModel,"count",1);compare(s.owner.selectedCity.id,"weather:home");
    }
}
