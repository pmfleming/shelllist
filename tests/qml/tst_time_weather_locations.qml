import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity
import "../../qml/Shelllist/Ui/MaterialIcons.js" as MaterialIcons

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
    function test_sameHeaderForEveryCityAndBothTabs_data() {return [{tag:"normal-dark",w:1280,scheme:Qt.Dark},{tag:"minimum-light",w:976,scheme:Qt.Light}];}
    function test_sameHeaderForEveryCityAndBothTabs(data) {
        Ui.Theme.previewColorScheme=data.scheme;
        const s=start(false,data.w);openDetails(s);compare(s.view.width,s.owner.openWindowWidth);
        for (const icon of ["add","home","my_location","location_on","explore"]) compare(MaterialIcons.name(icon),icon);
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
                for (const button of [primary,automatic,remove]) {
                    const p=button.mapToItem(s.view,0,0);
                    verify(p.x>=0 && p.x+button.width<=s.view.width,"all commands fit the real native canvas");
                }
                verify(primary.enabled && automatic.enabled);
                compare(remove.enabled,id==="city:1");
                verify(!primary.activeFocusOnTab && !automatic.activeFocusOnTab && !remove.activeFocusOnTab);
                const current=JSON.stringify([primary.x,primary.y,automatic.x,automatic.y,remove.x,remove.y,s.view.detailsItem.headerHeight]);
                if (geometry) compare(current,geometry);else geometry=current;
                capture(s.view,data.tag+"-"+id.replace(/:/g,"-")+"-"+tab);
            }
        }
        compare(mutations().length,0);
    }
    function test_roleIconsArrivalHomeAndDepartureRetainNavigation() {
        const s=start(false);select(s,"current-location");openDetails(s);
        s.owner.setDetailsTab("weather");
        wait(0);
        compare(s.owner.selectedCity.id,"current-location");
        const current=findChild(s.view,"timeWeatherLocation::current-location");compare(current.leadingIcon,"my_location");
        compare(findChild(s.view,"timeWeatherLocation::weather:home").leadingIcon,"home");
        s.owner.activity=Object.assign({},s.owner.activity,{locations:rows(true)});
        tryVerify(()=>s.owner.selectedCity.id==="weather:home");
        verify(s.owner.detailsOpen);compare(s.owner.detailsTab,"weather");
        capture(s.view,"at-home");
        const home=findChild(s.view,"timeWeatherLocation::weather:home");
        compare(findChild(home,"timeWeatherHomeCurrentIcon"),null);
        verify(home.accessibleName.includes("Home") && !home.accessibleName.includes("Current location"));
        compare(s.owner.cities.filter(c=>c.current).length,0);
        compare(findChild(s.view,"timeWeatherLocation::current-location"),null);
        s.owner.activity=Object.assign({},s.owner.activity,{locations:rows(false)});
        tryCompare(s.owner.cityModel,"count",3);compare(s.owner.selectedCity.id,"weather:home");
        compare(s.owner.cities.filter(c=>c.current).length,1);
        compare(mutations().length,0);
    }
    function test_unknownCurrentIsNotABlankResultAndHomeHasNoCurrentDecoration() {
        const s=start(true);
        const legacyHome=Object.assign({},rows(true)[0],{current:true,location_source:"ip",accuracy_meters:10000});
        const unknown={id:"current-location",label:"Current location",current:true,clock_unavailable:true};
        s.owner.activity=Object.assign({},s.owner.activity,{locations:[legacyHome,unknown]});
        tryCompare(s.owner.cityModel,"count",1);
        verify(!s.owner.cities.some(c=>c.id==="current-location"));
        const home=findChild(s.view,"timeWeatherLocation::weather:home");
        compare(home.leadingIcon,"home");compare(findChild(home,"timeWeatherHomeCurrentIcon"),null);
        verify(!home.accessibleName.includes("Current location"));
        verify(!home.accessibleName.includes("IP estimate"));
        compare(mutations().length,0);
    }
    function test_manualOverridesAutomaticAndReplacesTheSingleCurrentAfterAcknowledgement() {
        const s=start(false);s.locations.acceptControl(control(false,2));select(s,"city:1");openDetails(s);
        mouseClick(findChild(s.view,"detailAction:manual"));tryCompare(s.locations,"pickerMode","manual");
        mouseClick(findChild(findChild(s.view,"timeWeatherCityPicker"),"detailAction:accept"));
        const request=mutations()[0];compare(request.method,"location.setManual");
        compare(request.params.place.name,"Tokyo");
        verify(!s.locations.canAutomatic);
        compare(s.owner.cities.filter(c=>c.current).length,1);
        compare(s.owner.cities.find(c=>c.current).place.name,"Dublin","no optimistic Current replacement");
        reply(s,s.locations.mutationId,{location_control:Object.assign(control(true,3),{effective_place:request.params.place,operation_id:request.params.request_id,operation_status:"applied"})});
        verify(s.locations.canAutomatic);
        const current=Object.assign(city("current-location","Tokyo",false,true),{location_mode:"manual",location_source:"manual"});
        s.owner.activity=Object.assign({},s.owner.activity,{locations:rows(true).concat([current])});
        tryVerify(()=>s.owner.cities.find(c=>c.current)?.label==="Tokyo");
        compare(s.owner.cities.filter(c=>c.current).length,1);
        s.locations.returnAutomatic();const automatic=mutations()[1];
        reply(s,s.locations.mutationId,{location_control:Object.assign(control(false,4),{operation_id:automatic.params.request_id,operation_status:"applied"})});
        compare(s.owner.cities.find(c=>c.current).label,"Tokyo","Automatic waits for fresh accepted location");
        s.owner.activity=Object.assign({},s.owner.activity,{locations:rows(true)});
        tryCompare(s.owner.cityModel,"count",2);
        verify(!s.owner.cities.some(c=>c.current));
        compare(mutations().length,2);
    }
    function test_addIconAndShortcutDraftCancelAndStaleSearch() {
        const s=start(false);
        const plus=findChild(s.view,"fieldTrailingAction");verify(plus!==null);mouseClick(plus);
        tryCompare(s.locations,"pickerMode","add");
        const query=findChild(s.view,"searchChoiceQuery");tryVerify(()=>query.inputActiveFocus);
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
        capture(s.view,"manual-picker");
        mouseClick(findChild(findChild(s.view,"timeWeatherCityPicker"),"detailAction:accept"));
        tryVerify(()=>s.locations.busy);compare(mutations().length,1);
        s.locations.submitPicker();compare(mutations().length,1);
        const request=mutations()[0];compare(request.method,"location.setManual");
        compare(request.params.place.name,"Amsterdam");verify(s.locations.modalOpen,"admission is not acknowledgement");
        reply(s,s.locations.mutationId,{location_control:Object.assign(control(true,2),{operation_id:request.params.request_id,operation_status:"applied"})});
        compare(s.locations.pickerMode,"");compare(s.locations.controlState.revision,2);
    }
    function test_addAcknowledgementDoesNotRetargetReopenedPicker() {
        const s=start(false);s.view.listItem.focusSearch();keyClick(Qt.Key_A,Qt.AltModifier);
        tryCompare(s.locations,"pickerMode","add");
        s.locations.candidates=[place("Dublin","Europe/Dublin")];
        const choice=findChild(s.view,"searchChoiceCandidate");
        choice.forceActiveFocus();keyClick(Qt.Key_Down);
        // Native choice remains a modal draft: it never adds on its own.
        compare(mutations().length,0);
        s.locations.selectChoice("0");
        mouseClick(findChild(findChild(s.view,"timeWeatherCityPicker"),"detailAction:accept"));
        const request=s.locations.mutationId;compare(mutations()[0].method,"locations.add");
        keyClick(Qt.Key_Escape);tryVerify(()=>!s.locations.modalOpen);
        s.owner.filterText="Tokyo";
        const added=city("city:2","Dublin",false,false);
        reply(s,request,{id:added.id,activity:Object.assign({},s.owner.activity,{location_catalog:{revision:2,writable:true},locations:rows(false).concat([added])})});
        compare(s.owner.filterText,"Tokyo");compare(s.locations.pickerMode,"");
        compare(mutations().length,1);
    }
    function test_collapsedCommandsUseOneHostAndKeepEnterForInspection() {
        const s=start(true);verify(!s.owner.detailsOpen);
        keyClick(Qt.Key_L,Qt.AltModifier);tryCompare(s.locations,"pickerMode","manual");
        verify(!s.owner.detailsOpen);compare(mutations().length,0);
        keyClick(Qt.Key_Escape);tryVerify(()=>!s.locations.modalOpen);
        s.view.listItem.focusList();keyClick(Qt.Key_R,Qt.AltModifier);compare(mutations().length,1);
        reply(s,s.locations.mutationId,{location_control:Object.assign(control(false,2),{operation_id:s.locations.operationKey,operation_status:"applied"})});
        select(s,"city:1");s.view.listItem.focusList();keyClick(Qt.Key_D,Qt.AltModifier);
        tryVerify(()=>s.locations.removal!==null);compare(s.locations.removal.id,"city:1");
        keyClick(Qt.Key_Escape);tryVerify(()=>!s.locations.modalOpen);
        wait(0);s.view.listItem.focusList();tryVerify(()=>s.view.listItem.listFocused);
        verify(s.owner.hasSelection);verify(!s.owner.navigationBlocked);
        keyClick(Qt.Key_Return);tryVerify(()=>s.owner.detailsOpen);
        keyClick(Qt.Key_Return);verify(!s.locations.modalOpen);
        compare(mutations().length,1);
    }
    function test_hiddenPanelSettlesWithoutReopeningOrReplaying() {
        const s=start(true);
        if (s.locations.statusId) reply(s,s.locations.statusId,{location_control:control(true,1)});
        s.locations.openPicker("manual");s.locations.submitPicker();
        const id=s.locations.mutationId, operation=s.locations.operationKey;
        s.owner.deactivateUi();
        verify(s.locations.active);verify(!s.locations.modalOpen);
        reply(s,id,{location_control:Object.assign(control(true,2),{operation_id:operation,operation_status:"applied"})});
        verify(!s.locations.modalOpen);verify(!s.locations.active);compare(mutations().length,1);
        s.owner.activateUi("");wait(0);
        verify(!s.locations.modalOpen);compare(mutations().length,1);
    }
    function test_searchSingleFlightAndOwnedRecovery() {
        const s=start(true);s.locations.openPicker("add");
        s.locations.editQuery("Du");s.locations.search();const first=s.locations.searchId;
        s.locations.editQuery("Tok");s.locations.search();compare(s.locations.searchId,first);
        reply(s,first,{places:[place("Dublin","Europe/Dublin")]});compare(s.locations.candidates.length,0);
        s.locations.search();const second=s.locations.searchId;verify(second!==first);
        reply(s,second,{places:[place("Tokyo","Asia/Tokyo")]});compare(s.locations.candidates[0].name,"Tokyo");
        s.locations.closeModal();s.locations.openPicker("manual");s.locations.submitPicker();
        const mutation=s.locations.mutationId, operation=s.locations.operationKey;
        s.locations.finish(mutation,null,"Lost write reply");
        const status=s.locations.statusId;verify(status.length>0);
        reply(s,status,{location_control:Object.assign(control(true,2),{operation_id:operation,operation_status:"applied"})});
        compare(s.locations.error,"");verify(!s.locations.modalOpen);compare(mutations().length,1);
    }
    function test_staleRevisionFailuresAndTransportNeverReplay() {
        const s=start(true);openDetails(s);mouseClick(findChild(s.view,"detailAction:manual"));
        tryCompare(s.locations,"pickerMode","manual");
        s.locations.acceptControl(control(true,2));
        s.locations.submitPicker();compare(mutations().length,0);verify(s.locations.error.length>0);
        keyClick(Qt.Key_Escape);s.view.listItem.focusList();keyClick(Qt.Key_L,Qt.AltModifier);
        tryCompare(s.locations,"pickerMode","manual");
        s.locations.submitPicker();compare(mutations().length,1);
        const request=s.locations.mutationId;
        s.locations.finish(request,null,"Lost reply");
        verify(s.locations.error.includes("Lost reply"));
        s.locations.transportFailed("Disconnected",[]);
        s.locations.transportReady();
        compare(mutations().length,1);
        verify(!s.locations.canControl);
        keyClick(Qt.Key_Escape);
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
