import QtQuick
import Shelllist.Activity as Activity
import Shelllist.Ui as Ui
import Shelllist.Io as Io
import "../../shell" as Shell
import "../../shell/SurfaceCatalog.generated.js" as Catalog

DaemonTestCase {
    id: testCase
    name: "AgendaCalendar"
    when: windowShown
    width: 1900; height: 740; visible: true
    Component { id: factory; Activity.AgendaCalendarController {} }
    Component { id: agendaFactory; Activity.AgendaController {} }
    Component { id: registryFactory; Shell.SurfaceRegistry {} }
    Component { id: viewFactory; Activity.AgendaCalendarContent { anchors.fill: undefined } }
    Component { id: fitFactory; Ui.CalendarComposition {} }
    Component { id: viewportFactory; Ui.SurfaceViewport {} }
    property var views: []
    // Optional external review harness; normal interaction tests write no files.
    property string captureDirectory: ""
    function capture(content, name) {
        if (!captureDirectory) return;
        verify(waitForPolish(testCase.Window.window));
        let saved = false;
        verify(content.grabToImage(result=>{saved=result.saveToFile(captureDirectory + name + ".png");},
            Qt.size(Math.ceil(content.width),Math.ceil(content.height))));
        tryVerify(()=>saved);
    }
    function init() {
        calls = []; views = []; clientReady = true;
        Activity.AgendaRepository.catalogRevision = -1;
        Activity.AgendaRepository.records = ({});
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function cleanup() { for (const content of views) content.destroy(); wait(0); views = []; }
    function typeText(text) { for (const character of text) keyClick(character); }

    function owner() {
        const result = createTemporaryObject(factory, testCase, {availableScreenWidth: 1900, availableScreenHeight: 740});
        verify(result !== null);
        result.today = "2026-10-27";
        result.focusedDate = result.today;
        result.windowStart = result.monthFor(result.today) - 4;
        return result;
    }
    function view(controller) {
        const result = createTemporaryObject(viewFactory, testCase, {controller: controller, width: 1884, height: 700});
        verify(result !== null);
        result.width = Qt.binding(()=>controller.currentWindowWidth);
        views = views.concat([result]);
        verify(waitForPolish(testCase.Window.window));
        return result;
    }
    function test_independentLazyRoutesPreserveOtherSurfaces() {
        const agenda = Catalog.descriptors.find(item=>item.id === "agenda");
        const calendar = Catalog.descriptors.find(item=>item.id === "calendar");
        verify(agenda !== undefined && calendar !== undefined);
        for (const symbol of [agenda.icon,calendar.icon,"today","chevron_left","chevron_right","arrow_back"])
            verify(Ui.MaterialIcons.name(symbol).length > 0,"calendar commands/routes must resolve icon glyphs: " + symbol);
        verify(!Catalog.initiallyLoaded().agenda && !Catalog.initiallyLoaded().calendar);
        verify(Catalog.descriptors.some(item=>item.id === "time-weather"));
        verify(!Catalog.descriptors.some(item=>item.id === "activity"),"retired scheduling surface is alias only");
        verify(Catalog.requiresResidentState("notifications"));
        const registry=createTemporaryObject(registryFactory,testCase,{});
        verify(registry !== null);
        verify(!registry.isLoaded("agenda") && !registry.isLoaded("calendar"));
        verify(registry.select("activity"));
        compare(registry.currentId,"agenda","legacy IPC route canonicalizes before controller lookup");
        tryVerify(()=>registry.controllerFor("agenda") !== null);
        const routedAgenda=registry.controllerFor("agenda");
        verify(!registry.isLoaded("calendar"));
        verify(registry.select("calendar"));
        tryVerify(()=>registry.controllerFor("calendar") !== null);
        verify(registry.controllerFor("calendar").agendaController !== routedAgenda);
        compare(registry.controllerFor("time-weather"),null,"unrelated Weather content remains lazy");
        const standalone=createTemporaryObject(agendaFactory,testCase,{});
        const controller=owner();
        controller.chooseDay("2026-10-27");
        controller.agendaController.filterText="day query";
        standalone.filterText="all query";
        verify(standalone !== controller.agendaController);
        compare(standalone.dayScope,"");compare(controller.agendaController.dayScope,"2026-10-27");
        compare(standalone.filterText,"all query");compare(controller.agendaController.filterText,"day query");
    }
    function test_markerBridgeRejectsOldWindowAndClosedInvocation() {
        const controller=owner();
        controller.activateUi("");
        wait(100);
        const old=calls.filter(call=>call.method==="agenda.markers").slice(-1)[0];
        verify(old !== undefined);
        controller.windowStart += 1;
        wait(100);
        const current=calls.filter(call=>call.method==="agenda.markers").slice(-1)[0];
        verify(current !== undefined && current.id !== old.id);
        const data={days:[{date:"2026-10-27",event:true,task:true}],catalog_revision:1,today:"2026-10-27",timezone:"UTC"};
        const session=Io.DaemonSessions.sessions["bar-daemon"];
        session.client.response(old.id,{protocol:"bar-api",version:2,ok:true,data:data},"",old.route);
        compare(Object.keys(controller.markers).length,0);
        session.client.response(current.id,{protocol:"bar-api",version:2,ok:true,data:data},"",current.route);
        compare(controller.markers["2026-10-27"].task,true);
        controller.refresh();wait(100);
        const late=calls.filter(call=>call.method==="agenda.markers").slice(-1)[0];
        controller.deactivateUi();
        session.client.response(late.id,{protocol:"bar-api",version:2,ok:true,data:{days:[],catalog_revision:2,today:"2026-10-27",timezone:"UTC"}},"",late.route);
        compare(controller.catalogRevision,1);
        compare(calls.filter(call=>["agenda.patch","agenda.create","agenda.delete"].includes(call.method)).length,0);
    }
    function test_measuredFitExactBoundaries() {
        const fit = createTemporaryObject(fitFactory, testCase, {baseWidth: 453, adjacentWidth: 976, edgeMargin: 16, gap: 12, daySelected: true});
        const large = 1.5 * fit.baseWidth + fit.adjacentWidth + fit.gap + 2 * fit.edgeMargin;
        fit.availableWidth = large;
        compare(fit.calendarWidth, 679.5);
        fit.availableWidth = large - 0.5;
        compare(fit.calendarWidth, 453);
        fit.availableWidth = 453 + 976 + 12 + 32;
        compare(fit.calendarWidth, 453);
        fit.availableWidth -= 1;
        compare(fit.calendarWidth, 0);
        compare(fit.width, 976);
        fit.daySelected = false;
        compare(fit.calendarWidth, 679.5, "calendar never hides before day selection");
        fit.availableWidth=400;
        compare(fit.calendarWidth,453,"below W is unsupported, never a fourth shrink layout");
        compare(fit.supported,false);
    }
    function test_nativeScopedGridKeysAndPointer() {
        const controller = owner();
        const content = view(controller);
        controller.activateUi("");
        controller.returnToCalendar();
        const nav = content.calendarGrid.dateNavigation;
        nav.focusContent();
        tryCompare(nav, "activeFocus", true);
        keyClick(Qt.Key_Right); compare(controller.focusedDate, "2026-10-28");
        keyClick(Qt.Key_Down); compare(controller.focusedDate, "2026-11-04");
        keyClick(Qt.Key_PageUp); compare(controller.focusedDate, "2026-10-04");
        keyClick(Qt.Key_Left); compare(controller.focusedDate, "2026-10-03");
        keyClick(Qt.Key_Up); compare(controller.focusedDate, "2026-09-26");
        controller.agendaController.settingsOpen = true;
        keyClick(Qt.Key_Right);
        compare(controller.focusedDate, "2026-09-26", "modal blocks underlying grid");
        controller.agendaController.settingsOpen = false;
        nav.focusContent();
        controller.focusedDate="2024-01-31";
        keyClick(Qt.Key_PageDown);compare(controller.focusedDate,"2024-02-29","native month key clamps leap day");
        controller.focusedDate="2026-12-31";
        keyClick(Qt.Key_Right);compare(controller.focusedDate,"2027-01-01");
        controller.focusedDate="2026-09-26";
        keyClick(Qt.Key_Return);
        compare(controller.selectedDate, "2026-09-26");
        compare(controller.agendaController.dayScope, "2026-09-26");
        controller.returnToCalendar();
        controller.goToday();
        verify(waitForPolish(testCase.Window.window));
        const cell = findChild(content, "calendarDate:2026-10-27");
        verify(cell !== null);
        mouseClick(cell);
        compare(controller.selectedDate, "2026-10-27");
        verify(cell.Accessible.name.includes("27"));
    }
    function test_boundedMonthsBothDirectionsAndReopen() {
        const controller = owner();
        const content = view(controller);
        controller.activateUi("");
        const grid = content.calendarGrid;
        const months = grid.monthView;
        tryCompare(months, "contentY", 4 * grid.monthHeight);
        capture(content,"calendar-first-open");
        const original = controller.windowStart;
        months.contentY = grid.monthHeight + 19;
        compare(controller.windowStart, original - 3);
        compare(months.contentY, 4 * grid.monthHeight + 19);
        months.contentY = 6 * grid.monthHeight + 7;
        compare(controller.windowStart, original - 1);
        compare(controller.monthCount, 9);
        const start = controller.windowStart, offset = months.contentY;
        controller.deactivateUi();
        controller.activateUi("");
        compare(controller.windowStart, start);
        compare(controller.viewportOffset, offset);
        const bounds = controller.range();
        verify((new Date(bounds.to_date) - new Date(bounds.from_date)) / 86400000 < 370);
        const next = findChild(grid,"detailAction:next");
        verify(next !== null && next.width > 0 && next.height > 0);
        mouseClick(next);
        compare(Math.floor(months.contentY / grid.monthHeight), 5);
        keyClick(Qt.Key_P,Qt.AltModifier);
        compare(Math.floor(months.contentY / grid.monthHeight), 4);
        keyClick(Qt.Key_T,Qt.AltModifier);
        compare(controller.focusedDate, controller.today);
        compare(grid.dateNavigation.dateKey, controller.today);
    }
    function test_sharedInspectorEditorSurvivesMeasuredResizeAndReturn() {
        const controller = owner();
        const content = view(controller);
        controller.activateUi("");
        controller.chooseDay("2026-10-27");
        const agenda = controller.agendaController;
        const dayLabel=findChild(content,"agendaSelectedDay");
        verify(dayLabel !== null && dayLabel.text.includes("27") && dayLabel.text.includes("2026"));
        compare(dayLabel.activeFocusOnTab,false,"selected day is passive context, not an editor");
        if (captureDirectory) {
            controller.latestRead="capture";controller.latestRange=JSON.stringify(controller.range());
            controller.acceptMarkers("capture",{days:[{date:"2026-10-27",event:true,task:true},{date:"2026-10-28",event:false,task:true},{date:"2026-10-29",event:true,task:false}],catalog_revision:1,today:"2026-10-27",timezone:"UTC"},"");
        }
        const record = {id:"resize",kind:"event",source_id:"local",source_uid:null,revision:1,title:"Native title",notes:"",links:[],
            schedule:{mode:"date",start_date:"2026-10-27",end_date:"2026-10-27",start_unix_ms:null,end_unix_ms:null,timezone:null},
            created_unix_ms:1,modified_unix_ms:2,capabilities:{write:true,delete:true,complete:false},event:{location:"",people:[],status:"confirmed"},task:null};
        agenda.receiveList({generation:agenda.readGeneration,query:agenda.filterText,day:agenda.dayScope,epoch:Activity.AgendaRepository.epoch,append:false},
            {items:[record],next_cursor:null,catalog_revision:1,today:"2026-10-27",timezone:"UTC"}, "");
        content.agendaContent.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryCompare(agenda,"detailsExpansionProgress",1);
        tryCompare(content.calendarGrid.dateNavigation,"activeFocus",false,5000,"queued calendar activation cannot steal provider focus");
        tryVerify(()=>findChild(content,"agendaTitle") !== null);
        const title = findChild(content,"agendaTitle");
        capture(content,"calendar-three-pane-wide");
        if (captureDirectory) {
            // Review rendering is separate from the native transaction below.
            controller.availableScreenWidth=1600;capture(content,"calendar-three-pane-W");
            controller.availableScreenWidth=1280;capture(content,"calendar-hidden-inspector");
            controller.returnToCalendar();capture(content,"calendar-return");
            controller.availableScreenWidth=1900;controller.chooseDay("2026-10-27");
            wait(0);content.agendaContent.listItem.focusList();
        }
        title.focusInput(true); keySequence("Ctrl+A"); typeText("Unsubmitted title");
        compare(controller.composition.calendarWidth, 679.5);
        compare(content.calendarGrid.width,679.5);
        compare(content.agendaContent.x,679.5 + agenda.detailsGapWidth);
        compare(content.agendaContent.width,agenda.currentWindowWidth);
        verify(content.agendaContent.x + content.agendaContent.width <= controller.composition.budget);
        const originalDate = controller.focusedDate;
        keyClick(Qt.Key_Left); compare(controller.focusedDate,originalDate,"native editor arrows never navigate grid");
        controller.availableScreenWidth = 1600;
        compare(controller.composition.calendarWidth,453);
        compare(content.calendarGrid.width,453);
        compare(content.agendaContent.x,453 + agenda.detailsGapWidth);
        compare(findChild(content,"agendaTitle"),title);
        compare(title.text,"Unsubmitted title"); verify(title.inputActiveFocus);
        controller.availableScreenWidth = 1280;
        compare(controller.composition.calendarWidth,0);
        compare(content.calendarGrid.visible,false);
        compare(content.agendaContent.x,0);
        compare(content.agendaContent.width,agenda.currentWindowWidth);
        compare(findChild(content,"agendaTitle"),title); verify(title.inputActiveFocus);
        compare(title.text,"Unsubmitted title");
        compare(calls.filter(call=>call.method==="agenda.patch").length,0,"fit never saves drafts");
        keyClick(Qt.Key_Escape);
        tryCompare(title,"text","Native title");
        const start=controller.windowStart, offset=controller.viewportOffset;
        content.agendaContent.listItem.focusList(); keyClick(Qt.Key_B,Qt.AltModifier);
        tryCompare(controller,"returning",true);
        compare(controller.selectedDate,"2026-10-27");
        compare(controller.windowStart,start);compare(controller.viewportOffset,offset);
        tryCompare(content.calendarGrid.dateNavigation,"activeFocus",true);
        compare(content.agendaContent.inputScopeActive,false);
        keyClick(Qt.Key_A,Qt.AltModifier);
        compare(agenda.createOpen,false,"retained hidden provider commands cannot run under calendar focus");
        keyClick(Qt.Key_Tab);
        compare(content.calendarGrid.dateNavigation.activeFocus,true);
        const viewport=createTemporaryObject(viewportFactory,testCase,{width:300,height:200,canvasWidth:1040,horizontalOverflowAllowed:false});
        compare(viewport.contentWidth,300);compare(viewport.contentX,0);
        verify(!controller.geometry.horizontalOverflowAllowed);
    }
    function test_markerAtomicOwnershipRetainsCompletedPresence() {
        const controller = owner();
        controller.uiActive = true;
        controller.latestRead = "owned";
        controller.latestRange = JSON.stringify(controller.range());
        const data = {days: [{date: "2026-10-27", event: true, task: true}], catalog_revision: 9, today: "2026-10-27", timezone: "Europe/Amsterdam"};
        verify(!controller.acceptMarkers("old", data, ""));
        verify(controller.acceptMarkers("owned", data, ""));
        compare(controller.markers["2026-10-27"].task, true, "native presence includes completed tasks, no QML filtering");
        controller.latestRead = "bad";
        verify(!controller.acceptMarkers("bad", {days: [{date: "2026-10-27", event: true, task: 1}], catalog_revision: 10, today: "2026-10-27", timezone: "UTC"}, ""));
        compare(controller.catalogRevision, 9);
        compare(controller.markers["2026-10-27"].event, true);
        controller.latestRead = "failure";
        verify(!controller.acceptMarkers("failure", null, "offline"));
        compare(controller.markers["2026-10-27"].task, true);
    }
}
