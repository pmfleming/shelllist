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
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|Type .* unavailable).*/);
    }
    function cleanup() { for (const content of views) content.destroy(); wait(0); views = []; }
    function typeText(text) { for (const character of text) keyClick(character); }

    function owner() {
        const result = createTemporaryObject(factory, testCase, {availableScreenWidth: 1900, availableScreenHeight: 740});
        verify(result !== null);
        result.markerWindow.today = "2026-10-27";
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
        compare(agenda.icon,"view_list","Agenda route uses a registered Material symbol");
        for (const symbol of [agenda.icon,calendar.icon,"today","chevron_left","chevron_right","arrow_back"])
            verify(Ui.MaterialIcons.name(symbol).length > 0,"calendar commands/routes must resolve icon glyphs: " + symbol);
        verify(!Catalog.initiallyLoaded().agenda && !Catalog.initiallyLoaded().calendar);
        verify(Catalog.descriptors.some(item=>item.id === "time-weather"));
        verify(!Catalog.descriptors.some(item=>item.id === "activity"),"retired scheduling surface is alias only");
        verify(Catalog.requiresResidentState("notifications"));
        const registry=createTemporaryObject(registryFactory,testCase,{});
        verify(registry !== null);
        compare(Ui.MaterialIcons.name(registry.descriptorFor("agenda").icon),"view_list");
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
        const reader=controller.markerWindow;
        const consumer=session.consumers[reader.sharedConsumerId];
        compare(consumer.active,true,"extracted reader retains native subscription lifecycle");
        session.client.response(old.id,{protocol:"bar-api",version:2,ok:true,data:data},"",old.route);
        compare(Object.keys(controller.markers).length,0);
        session.client.response(current.id,{protocol:"bar-api",version:2,ok:true,data:data},"",current.route);
        compare(controller.markers["2026-10-27"].task,true);
        controller.refresh();wait(100);
        const invalidated=calls.filter(call=>call.method==="agenda.markers").slice(-1)[0];
        Activity.AgendaRepository.invalidated();
        session.client.response(invalidated.id,{protocol:"bar-api",version:2,ok:true,data:{days:[],catalog_revision:2,today:"2026-10-27",timezone:"UTC"}},"",invalidated.route);
        compare(controller.markerWindow.catalogRevision,1,"invalidation fences the old same-range read before debounce");
        wait(100);
        const eventInvalidated=calls.filter(call=>call.method==="agenda.markers").slice(-1)[0];
        verify(eventInvalidated.id !== invalidated.id);
        const subscription=session.client.subscriptions.find(item=>item.route.consumerId===reader.sharedConsumerId);
        verify(subscription !== undefined);
        emitBaseEvent("bar-daemon",subscription.route,{protocol:"bar-api",version:2,stream:"activity.changed",event:"changed",data:{}});
        compare(reader.latestRead,"","native events also fence the pending read immediately");
        wait(100);
        const late=calls.filter(call=>call.method==="agenda.markers").slice(-1)[0];
        verify(late.id !== eventInvalidated.id);
        controller.deactivateUi();
        compare(consumer.active,false);
        session.client.response(late.id,{protocol:"bar-api",version:2,ok:true,data:{days:[],catalog_revision:2,today:"2026-10-27",timezone:"UTC"}},"",late.route);
        compare(controller.markerWindow.catalogRevision,1);
        compare(calls.filter(call=>["agenda.patch","agenda.create","agenda.delete"].includes(call.method)).length,0);
    }
    function markerCalls() { return calls.filter(call=>call.method==="agenda.markers"); }
    function replyMarkers(request, revision, days) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id,
            {protocol:"bar-api",version:2,ok:true,data:{days:days,catalog_revision:revision,today:"2026-10-27",timezone:"UTC"}},"",request.route);
    }
    function test_markerBridgeBoundsStaleRecoveryAndPolling() {
        const controller=owner();controller.activateUi("");
        const reader=controller.markerWindow;
        const presence=[{date:"2026-10-27",event:true,task:true}];
        wait(100);replyMarkers(markerCalls().slice(-1)[0],9,presence);
        Activity.AgendaRepository.catalogRevision=10;
        const episodeStart=markerCalls().length;
        controller.refresh();wait(100);
        replyMarkers(markerCalls().slice(-1)[0],9,[]);
        wait(100);
        compare(markerCalls().length-episodeStart,2,"one explicit read plus one automatic stale restart");
        replyMarkers(markerCalls().slice(-1)[0],9,[]);
        wait(100);
        compare(markerCalls().length-episodeStart,2,"repeatedly stale replies cannot spin reads");
        verify(reader.error.length>0);
        compare(reader.catalogRevision,9);
        compare(controller.markers["2026-10-27"].task,true);
        reader.poll();wait(100);
        compare(markerCalls().length-episodeStart,2,"periodic fallback cannot renew a rejected episode's budget");
        controller.refresh();wait(100);
        compare(markerCalls().length-episodeStart,3,"explicit refresh starts a new bounded episode");
        replyMarkers(markerCalls().slice(-1)[0],10,[{date:"2026-10-27",event:true,task:1}]);
        reader.poll();wait(100);
        compare(markerCalls().length-episodeStart,3,"malformed replies pause instead of retrying");
        const session=Io.DaemonSessions.sessions["bar-daemon"];
        const subscription=session.client.subscriptions.find(item=>item.route.consumerId===reader.sharedConsumerId);
        verify(subscription !== undefined);
        emitBaseEvent("bar-daemon",subscription.route,{protocol:"bar-api",version:2,stream:"activity.changed",event:"gap",data:{}});
        wait(100);
        compare(markerCalls().length-episodeStart,4,"an acknowledged stream gap invalidates and re-enables reading");
        replyMarkers(markerCalls().slice(-1)[0],10,presence);
        compare(reader.error,"");compare(reader.catalogRevision,10);
        controller.deactivateUi();
    }
    function test_markerReconnectResetsAuthorityNotPresentation() {
        const controller=owner();controller.activateUi("");
        const reader=controller.markerWindow;
        const session=Io.DaemonSessions.sessions["bar-daemon"];
        const presence=[{date:"2026-10-27",event:true,task:true}];
        wait(100);replyMarkers(markerCalls().slice(-1)[0],9,presence);
        const repositoryConsumer=Object.values(session.consumers).find(consumer=>consumer.backend instanceof Activity.AgendaTransport);
        verify(repositoryConsumer !== undefined && !repositoryConsumer.active,"calendar-only first open does not activate the list repository transport");
        controller.refresh();wait(100);
        const old=markerCalls().slice(-1)[0];
        const acceptedDays=controller.markers;
        const generation=session.generation;
        clientReady=false;session.client.transportFailed("Daemon restarted from a verified older backup");
        compare(session.generation,generation+1);
        compare(reader.catalogRevision,9,"transport loss retains the accepted presentation revision");
        compare(controller.markers,acceptedDays,"disconnect does not replace the accepted day window");
        compare(reader.today,"2026-10-27");compare(reader.timezone,"UTC");
        compare(controller.markers["2026-10-27"].task,true);
        clientReady=true;wait(100);
        const fresh=markerCalls().slice(-1)[0];
        verify(fresh.route.generation !== old.route.generation);
        replyMarkers(fresh,3,[]);
        compare(reader.catalogRevision,3,"a fresh transport may accept the restored lower native revision");
        compare(Activity.AgendaRepository.catalogRevision,3);
        compare(Object.keys(controller.markers).length,0);
        replyMarkers(old,99,presence);
        compare(reader.catalogRevision,3,"an old transport cannot raise or replace the new authority");
        controller.deactivateUi();controller.activateUi("");wait(100);
        compare(session.generation,generation+1);
        replyMarkers(markerCalls().slice(-1)[0],2,presence);
        compare(reader.catalogRevision,3,"ordinary same-session activation must preserve the revision floor");
        clientReady=false;clientReady=true;wait(100);
        replyMarkers(markerCalls().slice(-1)[0],2,presence);
        compare(reader.catalogRevision,3,"ready toggles alone are not a new transport generation");
        controller.deactivateUi();
        clientReady=false;session.client.transportFailed("Inactive calendar missed the daemon restart");
        compare(reader.catalogRevision,3);
        clientReady=true;controller.activateUi("");wait(100);
        replyMarkers(markerCalls().slice(-1)[0],1,presence);
        compare(reader.catalogRevision,1,"inactive reader also adopts the actual new transport authority");
        compare(calls.filter(call=>["agenda.patch","agenda.create","agenda.delete"].includes(call.method)).length,0,"reconnect never replays a mutation");
        controller.deactivateUi();
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
    function calendarRecord(id) {
        return {id:id,kind:"event",source_id:"local",source_uid:null,revision:1,title:"Native title",notes:"",links:[],
            schedule:{mode:"date",start_date:"2026-10-27",end_date:"2026-10-27",start_unix_ms:null,end_unix_ms:null,timezone:null},
            created_unix_ms:1,modified_unix_ms:2,capabilities:{write:true,delete:true,complete:false},event:{location:"",people:[],status:"confirmed"},task:null};
    }
    function test_sourceDiagnosticVisibleBeforeDaySelectionAndNonfatal() {
        const controller=owner();const content=view(controller);controller.activateUi("");
        tryVerify(()=>markerCalls().length>0,5000,"marker-only first open dispatches its native read");
        const request=markerCalls().slice(-1)[0];
        const sourceError="unsupported iCalendar recurrence; previous import retained: "+"旅行".repeat(40);
        const presence=[{date:"2026-10-27",event:true,task:false}];
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id,
            {protocol:"bar-api",version:2,ok:true,data:{days:presence,catalog_revision:1,today:"2026-10-27",timezone:"UTC",failing_source_count:1,source_error:sourceError}},"",request.route);
        compare(controller.selectedDate,"");compare(controller.agendaController.uiActive,false);
        const feedback=findChild(content.calendarGrid,"panelFeedback");
        tryCompare(feedback,"visible",true);
        const label=findChild(feedback,"feedbackText");
        tryVerify(()=>label.text.includes("unsupported iCalendar recurrence"));
        verify(label.implicitHeight <= label.height,"long native source labels use a measured one-line summary");
        compare(controller.markers["2026-10-27"].event,true);
        compare(controller.markerWindow.error,"");compare(controller.navigationBlocked,false);
        capture(content,"calendar-source-warning");
        controller.availableScreenWidth=600;
        compare(content.calendarGrid.width,453);
        verify(waitForPolish(testCase.Window.window));
        verify(label.text.includes("unsupported iCalendar recurrence"));
        verify(label.implicitHeight <= label.height);
        capture(content,"calendar-source-warning-W");
        controller.availableScreenWidth=1900;
        controller.chooseDay("2026-10-27");
        const agenda=controller.agendaController;
        agenda.receiveList({generation:agenda.readGeneration,query:agenda.filterText,day:agenda.dayScope,epoch:Activity.AgendaRepository.epoch,append:false},
            {items:[calendarRecord("usable-local")],next_cursor:null,catalog_revision:1,today:"2026-10-27",timezone:"UTC",failing_source_count:1,source_error:sourceError},"");
        compare(agenda.items.length,1);compare(agenda.canWrite(agenda.selectedItem),true,"nonfatal imported-source error does not disable local edits");
        content.agendaContent.listItem.focusList();keyClick(Qt.Key_Right);
        tryCompare(agenda,"detailsExpansionProgress",1);
        tryVerify(()=>findChild(content,"agendaTitle") !== null);
        const title=findChild(content,"agendaTitle");
        tryVerify(()=>content.agendaContent.detailsNavigation.targets.indexOf(title)>=0);
        wait(0);
        title.focusInput(true);
        tryCompare(title.editSession,"active",true);
        compare(content.agendaContent.detailsNavigation.editorTarget,title);
        keySequence("Ctrl+A");typeText("Usable local draft");
        compare(title.text,"Usable local draft");keyClick(Qt.Key_Escape);tryCompare(title,"text","Native title");
        compare(calls.filter(call=>["agenda.patch","agenda.create","agenda.delete"].includes(call.method)).length,0);
        const previous=markerCalls().slice(-1)[0].id;
        controller.refresh();
        tryVerify(()=>markerCalls().slice(-1)[0]?.id !== previous);
        const healthy=markerCalls().slice(-1)[0];
        Io.DaemonSessions.sessions["bar-daemon"].client.response(healthy.id,
            {protocol:"bar-api",version:2,ok:true,data:{days:presence,catalog_revision:2,today:"2026-10-27",timezone:"UTC",failing_source_count:0,source_error:null}},"",healthy.route);
        compare(controller.markerWindow.sourceError,"");compare(controller.markerWindow.failingSourceCount,0);
        compare(feedback.visible,false);compare(agenda.items.length,1);
        controller.deactivateUi();
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
            const reader=controller.markerWindow;
            reader.latestRead="capture";reader.latestRange=reader.rangeKey;
            reader.accept("capture",{days:[{date:"2026-10-27",event:true,task:true},{date:"2026-10-28",event:false,task:true},{date:"2026-10-29",event:true,task:false}],catalog_revision:1,today:"2026-10-27",timezone:"UTC"},"");
        }
        const record = calendarRecord("resize");
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
        tryVerify(()=>content.agendaContent.detailsNavigation.targets.indexOf(title)>=0);
        wait(0);
        title.focusInput(true);
        tryCompare(title.editSession,"active",true);
        compare(content.agendaContent.detailsNavigation.editorTarget,title);
        keySequence("Ctrl+A"); typeText("Unsubmitted title");
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
        verify(title.editSession.active);compare(content.agendaContent.detailsNavigation.editorTarget,title);
        controller.availableScreenWidth = 1280;
        compare(controller.composition.calendarWidth,0);
        compare(content.calendarGrid.visible,false);
        compare(content.agendaContent.x,0);
        compare(content.agendaContent.width,agenda.currentWindowWidth);
        compare(findChild(content,"agendaTitle"),title); verify(title.inputActiveFocus);
        verify(title.editSession.active);compare(content.agendaContent.detailsNavigation.editorTarget,title);
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
        const reader = controller.markerWindow;
        reader.latestRead = "owned";
        reader.latestRange = reader.rangeKey;
        const data = {days: [{date: "2026-10-27", event: true, task: true}], catalog_revision: 9, today: "2026-10-27", timezone: "Europe/Amsterdam"};
        verify(!reader.accept("old", data, ""));
        verify(reader.accept("owned", data, ""));
        verify(!reader.accept("owned", data, ""), "an accepted read is consumed once");
        verify(!reader.accept("", data, ""), "empty response ID is never an owned read");
        compare(controller.markers["2026-10-27"].task, true, "native presence includes completed tasks, no QML filtering");
        const freshDay = {date: "2026-10-28", event: false, task: true};
        const invalidWindows = [
            {days: [freshDay, freshDay]},
            {days: [freshDay, {date: "2026-10-29", event: true, task: 1}]},
            {days: [freshDay, {date: "2030-01-01", event: true, task: false}]},
            {days: [freshDay, {date: "2026-10-7", event: true, task: false}]},
            {today: "2026-02-30"}, {timezone: null}, {catalog_revision: 9007199254740992},
            {failing_source_count: -1, source_error: "failure"}, {failing_source_count: 1, source_error: null},
            {failing_source_count: 1, source_error: "x".repeat(1025)}
        ];
        for (const patch of invalidWindows) {
            reader.latestRead = "bad";
            verify(!reader.accept("bad", Object.assign({}, data, patch), ""));
            compare(reader.latestRead, "", "malformed owned replies still retire only their read");
            compare(reader.catalogRevision, 9);
            compare(reader.timezone, "Europe/Amsterdam");
            compare(controller.today, "2026-10-27");
            compare(Object.keys(controller.markers).length, 1, "invalid suffix cannot publish a valid prefix");
            compare(controller.markers["2026-10-27"].event, true);
        }
        Activity.AgendaRepository.catalogRevision = 10;
        reader.latestRead = "stale-revision";
        verify(!reader.accept("stale-revision", data, ""));
        compare(reader.catalogRevision, 9, "another view's newer revision fences this read");
        reader.latestRead = "failure";
        verify(!reader.accept("failure", null, "offline"));
        compare(reader.error, "offline");
        compare(controller.markers["2026-10-27"].task, true);
        controller.deactivateUi();
    }
}
