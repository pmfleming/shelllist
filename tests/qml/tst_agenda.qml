import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Activity as Agenda
import Shelllist.Io as Io

DaemonTestCase {
    id: testCase
    name: "Agenda"
    when: windowShown
    visible: true
    width: 1100
    height: 700
    Component { id: ownerFactory; Agenda.AgendaController {} }
    Component { id: viewFactory; Agenda.AgendaContent {} }
    Component {
        id: earlierConsumerFactory
        Io.DaemonBackend {
            daemonName: "bar-daemon"
            active: false
            property int synchronizedEpoch: -1
            property int synchronizedGeneration: -1
            property double synchronizedFloor: -2
            onTransportFailed: function(message, lostIds) {
                synchronizedGeneration = Agenda.AgendaRepository.synchronizeTransportAuthority();
                synchronizedEpoch = Agenda.AgendaRepository.epoch;
                synchronizedFloor = Agenda.AgendaRepository.catalogRevision;
            }
        }
    }
    Component {
        id: responseObserverFactory
        Connections {
            required property string owner
            property int mutations: 0
            target: Agenda.AgendaRepository
            function onResponse(responseOwner, purpose, context, data, error) { if (responseOwner === owner && purpose === "mutation") mutations++; }
        }
    }
    property string captureDirectory: ""
    property var views: []
    property int originalScheme: Ui.Theme.previewColorScheme
    function init() { calls = []; views = []; clientReady = true; originalScheme = Ui.Theme.previewColorScheme; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign to non-existent property|Type .* unavailable|Unable to assign).*/); }
    function cleanup() { for (const view of views) view.destroy(); wait(0); views = []; Ui.Theme.previewColorScheme = originalScheme; }
    function capture(s,name) {
        const directory=captureDirectory || Quickshell.env("SHELLLIST_AGENDA_REVIEW_DIR") || "";
        if (!directory) return;
        wait(150);verify(waitForPolish(s.view.Window.window));let saved=false;
        verify(s.view.grabToImage(image=>{saved=image.saveToFile(directory+name+".png");}));tryVerify(()=>saved);
    }
    function typeText(text) { for (const character of text) { if (character==="\n") keyClick(Qt.Key_Return,Qt.ShiftModifier); else keyClick(character); } }
    function clickRevealed(s,name) {
        const button=field(s,name);let parent=button.parent;
        while(parent && !(parent instanceof Ui.DetailFlickable)) parent=parent.parent;
        if(parent) parent.revealItem(button);
        verify(waitForPolish(s.view.Window.window));mouseClick(button);
    }
    function item(id, kind, revision) {
        return {id:id,kind:kind||"task",source_id:"local",source_uid:null,revision:revision||1,title:"Item "+id,notes:"Plain notes",links:[],
            schedule:{mode:"date",start_date:null,end_date:null,start_unix_ms:null,end_unix_ms:null,timezone:null},
            created_unix_ms:1,modified_unix_ms:2,capabilities:{write:true,delete:true,complete:kind!=="event"},
            event:kind==="event"?{location:"Office",people:["Alex"],status:"confirmed"}:null,
            task:kind==="event"?null:{priority:3,status:"needs-action",completed:false,completed_unix_ms:null,checklist:[{id:"step1",text:"First",checked:false},{id:"step2",text:"Second",checked:true}]}};
    }
    function windowData(items, revision, cursor) { return {items:items,next_cursor:cursor||null,catalog_revision:revision||1,today:"2026-10-27",timezone:"Europe/Amsterdam"}; }
    function accept(owner, items, revision, cursor) {
        owner.receiveList({generation:owner.readGeneration,query:owner.filterText,day:owner.dayScope,epoch:Agenda.AgendaRepository.epoch,append:false},windowData(items,revision,cursor),"");
    }
    function start(items) {
        Agenda.AgendaRepository.records = ({}); Agenda.AgendaRepository.catalogRevision = -1;
        const owner = createTemporaryObject(ownerFactory,testCase,{uiActive:true});
        verify(owner!==null);
        const view = createTemporaryObject(viewFactory,testCase,{controller:owner,width:owner.openWindowWidth,height:height});
        verify(view!==null); views = views.concat([view]);
        accept(owner,items||[item("a"),item("b","event")]);
        tryCompare(owner.itemModel,"count",items?items.length:2);
        view.listItem.focusList();
        return {owner:owner,view:view};
    }
    function open(s) {
        s.view.listItem.focusList();keyClick(Qt.Key_Right);
        tryCompare(s.owner,"detailsExpansionProgress",1);
        tryVerify(()=>s.view.detailsNavigation.contentReady);
    }
    function mutations() { return calls.filter(call=>["agenda.create","agenda.patch","agenda.delete"].includes(call.method)); }
    function finish(s,data,error) { const op=s.owner.operation; verify(op!==null); s.owner.receiveMutation(op,data,error||""); }
    function success(s,record,revision) { finish(s,{request_id:s.owner.operation.request_id,item:record,catalog_revision:revision||2}); }
    function field(s,name) { tryVerify(()=>findChild(s.view,name)!==null,5000,name); return findChild(s.view,name); }
    function edit(s,name,text,save) {
        const control=field(s,name);
        tryVerify(()=>s.view.detailsNavigation.targets.indexOf(control)>=0);
        wait(0);
        if (control.focusInput) control.focusInput(true); else control.forceActiveFocus();
        keySequence("Ctrl+A");keyClick(Qt.Key_Backspace);typeText(text);
        if(save!==undefined)keyClick(save);
        return control;
    }
    function respond(call,data,error) {
        const session=Io.DaemonSessions.sessions["bar-daemon"];
        session.client.response(call.id,{protocol:"bar-api",version:2,ok:!error,data:data,error:error?{message:error,code:"fixture"}:undefined},"",call.route);
    }
    function test_transportAuthorityEarlierConsumerResetPreservesDraftAndAcceptsLowerBackup() {
        const s=start();const high=item("a","task",9);high.title="Accepted before restart";accept(s.owner,[high],90);
        open(s);const title=edit(s,"agendaTitle","Local before restart");
        const transaction=findChild(title,"agendaInlineEdit");verify(transaction!==null);compare(transaction.snapshot.item.revision,9);
        tryVerify(()=>calls.some(call=>call.method==="agenda.list"));
        const oldRead=calls.filter(call=>call.method==="agenda.list"&&call.params.query==="").slice(-1)[0];
        const other=createTemporaryObject(ownerFactory,testCase,{uiActive:true,filterText:"other"});accept(other,[item("pending")],90);
        other.complete(other.selectedItem);compare(mutations().length,1);
        const uncertain=other.operation.request_id;
        const observer=createTemporaryObject(responseObserverFactory,testCase,{owner:other.ownerId});
        const early=createTemporaryObject(earlierConsumerFactory,testCase);
        const session=Io.DaemonSessions.sessions["bar-daemon"];
        // Model a calendar consumer registered before the repository. Exercise
        // Core.failSession's real generation advance/consumer callback order.
        const reordered={[early.sharedConsumerId]:session.consumers[early.sharedConsumerId]};
        for (const id of Object.keys(session.consumers)) if (id!==early.sharedConsumerId) reordered[id]=session.consumers[id];
        session.consumers=reordered;
        const generation=session.generation, epoch=Agenda.AgendaRepository.epoch;
        clientReady=false;session.client.transportFailed("Backup restart");
        compare(early.synchronizedGeneration,generation+1);compare(early.synchronizedFloor,-1);
        compare(early.synchronizedEpoch,epoch+1);compare(Agenda.AgendaRepository.epoch,epoch+1);
        compare(Agenda.AgendaRepository.authorityGeneration,session.generation);compare(Object.keys(Agenda.AgendaRepository.records).length,0);
        compare(observer.mutations,1);compare(other.failedOperation.request_id,uncertain);compare(other.operation,null);
        compare(field(s,"agendaTitle"),title);compare(title.text,"Local before restart");compare(s.owner.selectedItem.title,"Accepted before restart");compare(transaction.snapshot.item.revision,9);
        Agenda.AgendaRepository.synchronizeTransportAuthority();compare(Agenda.AgendaRepository.epoch,epoch+1);
        clientReady=true;s.owner.refresh();
        tryVerify(()=>calls.some(call=>call.method==="agenda.list"&&call.params.query===""&&call.route.generation===session.generation));
        const read=calls.filter(call=>call.method==="agenda.list"&&call.params.query===""&&call.route.generation===session.generation).slice(-1)[0];
        const restored=item("a");restored.title="Restored lower revision";
        respond(read,windowData([Agenda.AgendaRepository.summaryOf(restored)],1));
        tryVerify(()=>calls.some(call=>call.method==="agenda.get"&&call.params.id==="a"&&call.route.generation===session.generation));
        const get=calls.filter(call=>call.method==="agenda.get"&&call.params.id==="a"&&call.route.generation===session.generation).slice(-1)[0];respond(get,{item:restored,catalog_revision:1});
        compare(Agenda.AgendaRepository.catalogRevision,1);compare(s.owner.selectedItem.revision,1);
        compare(field(s,"agendaTitle"),title);compare(title.text,"Local before restart");compare(transaction.snapshot.item.revision,9);
        respond(oldRead,windowData([item("obsolete","task",999)],999));compare(Agenda.AgendaRepository.catalogRevision,1);compare(s.owner.items[0].id,"a");
        Agenda.AgendaRepository.synchronizeTransportAuthority();compare(Agenda.AgendaRepository.catalogRevision,1);compare(Agenda.AgendaRepository.epoch,epoch+1);
        compare(mutations().length,1,"no mutation replay after authority recovery");compare(observer.mutations,1);
        keyClick(Qt.Key_Return);compare(mutations().length,2);compare(mutations()[1].params.expected_revision,9,"explicit save retains pre-reset begin revision");
    }
    function test_inlineBeginSnapshotNeverRebases_data() {
        return [
            {tag:"title",kind:"task",name:"agendaTitle",fieldKey:"title",text:"Local title"},
            {tag:"notes",kind:"task",name:"agendaNotes",fieldKey:"notes",text:"Local notes",notes:true},
            {tag:"priority",kind:"task",name:"agendaField::task.priority",fieldKey:"task.priority",text:"8"},
            {tag:"task-status",kind:"task",name:"agendaField::task.status",fieldKey:"task.status",text:"local-progress"},
            {tag:"location",kind:"event",name:"agendaField::event.location",fieldKey:"event.location",text:"Studio"},
            {tag:"people",kind:"event",name:"agendaField::event.people",fieldKey:"event.people",text:"Alex\nSam"},
            {tag:"event-status",kind:"event",name:"agendaField::event.status",fieldKey:"event.status",text:"cancelled"},
            {tag:"link-label",kind:"task",name:"agendaLinkLabel::link1",fieldKey:"links",childId:"link1",childField:"label",text:"Local label",notes:true},
            {tag:"link-url",kind:"task",name:"agendaLinkUrl::link1",fieldKey:"links",childId:"link1",childField:"url",text:"https://local.example",notes:true},
            {tag:"checklist-text",kind:"task",name:"agendaStep::step1",fieldKey:"task.checklist",childId:"step1",childField:"text",text:"Local step",notes:true}
        ];
    }
    function test_inlineBeginSnapshotNeverRebases(data) {
        const original=item("a",data.kind);original.links=[{id:"link1",label:"Old label",url:"https://old.example"}];
        const s=start([original]);open(s);
        if(data.notes) {s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);}
        const editor=edit(s,data.name,data.text);const transaction=findChild(editor,"agendaInlineEdit");verify(transaction!==null);
        compare(transaction.snapshot.item.id,"a");compare(transaction.snapshot.item.revision,1);
        const external=s.owner.copy(original);external.revision=2;external.title="Native title";external.notes="Native notes";
        external.links=[{id:"new-link",label:"New",url:"https://new.example"},{id:"link1",label:"Native label",url:"https://native.example"}];
        if(data.kind==="task") {
            external.task.priority=99;external.task.status="native-progress";
            external.task.checklist[0].text="Native step";external.task.checklist[0].checked=true;
            external.task.checklist.unshift({id:"new-step",text:"Native inserted step",checked:false});
        } else external.event={location:"Native room",people:["Native person"],status:"tentative"};
        s.owner.requestItem(s.owner.selectedSummary,false);
        const get=calls.filter(call=>call.method==="agenda.get").slice(-1)[0];respond(get,{item:external,catalog_revision:2});
        tryCompare(s.owner.selectedItem,"revision",2);wait(0);
        compare(field(s,data.name),editor);compare(editor.text,data.text);compare(transaction.snapshot.item.revision,1);
        let value=data.fieldKey==="task.priority"?Number(data.text):data.fieldKey==="event.people"?data.text.split("\n"):data.text;
        const parts=data.fieldKey.split(".");
        if(data.childId) {
            const values=s.owner.copy(parts.length===1?original[data.fieldKey]:original[parts[0]][parts[1]]);
            values.find(child=>child.id===data.childId)[data.childField]=data.text;value=values;
        }
        const patch=parts.length===1?{[data.fieldKey]:value}:{[parts[0]]:Object.assign({},original[parts[0]],{[parts[1]]:value})};
        keyClick(Qt.Key_Return);compare(mutations().length,1);
        compare(mutations()[0].params.id,"a");compare(mutations()[0].params.expected_revision,1,"save cannot silently rebase to native revision2");
        compare(JSON.stringify(mutations()[0].params.patch),JSON.stringify(patch),"compound siblings and child identity belong to begin snapshot");
        compare(transaction.snapshot,null);
        finish(s,null,"Revision conflict");compare(s.owner.savedDrafts["a:"+data.fieldKey].expected_revision,1);
        compare(JSON.stringify(s.owner.valueFor(s.owner.selectedItem,data.fieldKey,null)),JSON.stringify(value));
        if(data.fieldKey==="title") {
            edit(s,data.name,"Corrected failed draft",Qt.Key_Return);compare(mutations()[1].params.expected_revision,1,"failed draft re-entry is not implicit reviewed rebase");
        }
    }
    function test_nonfatalSourceDiagnosticVisibleWithUsableLocalRecord() {
        const record=item("usable");const s=start([record]);
        tryVerify(()=>calls.some(call=>call.method==="agenda.list"));
        const read=calls.filter(call=>call.method==="agenda.list").slice(-1)[0];
        const data=windowData([Agenda.AgendaRepository.summaryOf(record)],1);data.failing_source_count=2;data.source_error="unsupported iCalendar recurrence; previous import retained: "+"長い名前".repeat(50);
        respond(read,data);compare(s.owner.failingSourceCount,2);compare(s.owner.sourceError,data.source_error);
        compare(s.owner.items[0].id,"usable");verify(s.owner.canWrite(s.owner.selectedItem));
        const feedback=field(s,"agendaSourceFeedback");verify(feedback.active);compare(feedback.tone,"warning");verify(feedback.text.includes("2"));
        const visible=field(s,"feedbackText");tryVerify(()=>visible.text.includes("recurrence"));verify(visible.visible);capture(s,"agenda-source-diagnostic");
        s.view.listItem.focusSearch();keyClick(Qt.Key_G,Qt.AltModifier);tryCompare(s.owner,"settingsOpen",true);
        verify(field(s,"agendaSettingsDialog").detail.includes(data.source_error));verify(field(s,"agendaSettingsDialog").detail.includes("2 source issue(s)"));keyClick(Qt.Key_Escape);
        s.view.listItem.focusList();keyClick(Qt.Key_Return);compare(mutations().length,1,"nonfatal source diagnostic cannot block local CRUD");
        const completed=item("usable","task",2);completed.task.completed=true;success(s,completed);
        compare(s.owner.items.length,1);compare(s.owner.failingSourceCount,2);verify(feedback.active,"local acknowledgement does not clear a source failure");
    }
    function test_importUnknownProvenanceDoesNotMasqueradeAsEpoch_data() {
        return [{tag:"import-unknown",source:"work",timestamp:0,unknown:true},{tag:"local-real-epoch",source:"local",timestamp:0,unknown:false},{tag:"import-known-time",source:"work",timestamp:1,unknown:false}];
    }
    function test_importUnknownProvenanceDoesNotMasqueradeAsEpoch(data) {
        const record=item("provenance","event");record.source_id=data.source;record.source_uid="source-uid";
        record.capabilities={write:false,delete:false,complete:false};record.created_unix_ms=data.timestamp;record.modified_unix_ms=data.timestamp;
        const s=start([record]);open(s);s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);keyClick(Qt.Key_Tab,Qt.ControlModifier);
        tryCompare(s.owner,"detailsTab","information");
        for (const key of ["created","modified"]) {
            const value=field(s,"agendaInformation::"+key).value;
            if(data.unknown) compare(value,"Unknown");else {verify(value!=="Unknown"&&value!=="—");verify(value.includes("1970"));}
        }
        compare(s.owner.selectedItem.created_unix_ms,data.timestamp);compare(mutations().length,0);
    }
    function test_realBridgeStaleReadsAndReceiptWithoutMutationReplay() {
        const s=start();tryVerify(()=>calls.some(call=>call.method==="agenda.list"));
        const old=calls.filter(call=>call.method==="agenda.list").slice(-1)[0];
        s.owner.filterText="new query";
        tryVerify(()=>calls.some(call=>call.method==="agenda.list"&&call.params.query==="new query"));
        const current=calls.filter(call=>call.method==="agenda.list"&&call.params.query==="new query").slice(-1)[0];verify(current.id!==old.id);
        respond(old,windowData([item("obsolete")],1));compare(s.owner.items[0].id,"a");
        respond(current,windowData([item("accepted")],2));tryCompare(s.owner.selectedItem,"id","accepted");
        s.view.listItem.focusList();keyClick(Qt.Key_Return);compare(mutations().length,1);
        const mutation=mutations()[0];
        const session=Io.DaemonSessions.sessions["bar-daemon"];
        session.client.transportFailed("Connection lost after send");
        tryCompare(s.owner,"operation",null);verify(s.owner.failedOperation!==null);
        s.owner.refresh();wait(150);compare(mutations().length,1,"reconnect/refresh never replays mutation");
        s.owner.checkReceipt();wait(0);
        const receipt=calls.filter(call=>call.method==="agenda.receipt").slice(-1)[0];verify(receipt!==undefined);
        compare(receipt.params.request_id,mutation.params.request_id);
        const completed=item("accepted","task",3);completed.task.completed=true;
        respond(receipt,{receipt:{request_id:mutation.params.request_id,item:completed,catalog_revision:3}});
        tryCompare(s.owner,"failedOperation",null);compare(s.owner.selectedItem.task.completed,true);
        compare(mutations().length,1);
    }
    function test_nativeReorderRetainsSelectedIdentityAndActiveKindSpecificEditor() {
        const s=start();open(s);const status=edit(s,"agendaField::task.status","Unsubmitted status");
        accept(s.owner,[item("b","event"),item("a")],2);wait(0);
        compare(s.owner.selectedSummary.id,"a");compare(s.owner.selectionModel.selectedIndex,1);
        compare(field(s,"agendaField::task.status"),status);compare(status.text,"Unsubmitted status");verify(status.activeFocus);compare(mutations().length,0);
        keyClick(Qt.Key_Escape);tryCompare(status,"text","needs-action");
    }
    function test_selectedRemovalDiscardsOnlyUnsubmittedEditorAndRetainsExpansion() {
        const s=start();open(s);edit(s,"agendaField::task.status","Unsubmitted status");
        Agenda.AgendaRepository.removeRecord("a",2);wait(0);
        compare(s.owner.selectedSummary.id,"b");verify(s.owner.detailsOpen);compare(mutations().length,0);
        tryVerify(()=>findChild(s.view,"agendaField::event.status")!==null);
        compare(field(s,"agendaField::event.status").text,"confirmed");
        Agenda.AgendaRepository.removeRecord("b",3);tryCompare(s.owner,"detailsOpen",false);compare(s.owner.items.length,0);compare(mutations().length,0);
    }
    function test_receiptCannotRetireNewerSubmittedDraft() {
        const s=start();open(s);edit(s,"agendaTitle","First",Qt.Key_Return);finish(s,null,"Uncertain first write");
        const previous=s.owner.failedOperation;s.owner.checkReceipt();
        const receipt=calls.filter(call=>call.method==="agenda.receipt").slice(-1)[0];verify(receipt!==undefined);
        edit(s,"agendaTitle","Second",Qt.Key_Return);const current=s.owner.operation;verify(current.request_id!==previous.request_id);
        const committed=item("a","task",2);committed.title="First";
        respond(receipt,{receipt:{request_id:previous.request_id,item:committed,catalog_revision:2}});
        compare(s.owner.operation.request_id,current.request_id,"old receipt cannot consume a newer mutation");
        finish(s,null,"Revision conflict");compare(s.owner.valueFor(s.owner.selectedItem,"title",""),"Second");compare(s.owner.failedOperation.request_id,current.request_id);compare(mutations().length,2);
    }
    function parsed(schedule,error) {
        const request=calls.filter(call=>call.method==="agenda.schedule").slice(-1)[0];verify(request!==undefined);
        respond(request,error?null:{schedule:schedule},error);
    }
    function test_nativeLongContentAppearanceAndInfo_data() { return [{tag:"light",scheme:Qt.Light},{tag:"dark",scheme:Qt.Dark}]; }
    function test_nativeLongContentAppearanceAndInfo(data) {
        Ui.Theme.previewColorScheme=data.scheme;
        for (const icon of ["calendar_month","checklist","check","restore","today","find_in_page","edit","article","info","link","add"]) verify(Ui.MaterialIcons.name(icon).length>0,"registered icon: "+icon);
        const record=item("long","event");record.title="Planning a shared agenda release with a deliberately long title for wrapping and accessible full identity";
        record.notes="Plain multiline notes.\n".repeat(80);record.links=[{id:"link",label:"Release checklist",url:"https://example.org/release"}];
        const appearance=data.scheme===Qt.Dark?"dark":"light";
        const s=start([record]);open(s);capture(s,"agenda-"+appearance+"-details");
        s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);
        tryVerify(()=>findChild(s.view,"agendaNotes")!==null);compare(field(s,"agendaNotes").text.length,record.notes.length);
        capture(s,"agenda-"+appearance+"-notes");
        s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);capture(s,"agenda-"+appearance+"-information");
        tryVerify(()=>s.view.detailsNavigation.targets.every(target=>target instanceof Ui.DetailFlickable),5000,"information has only passive scrolling fallback");
    }
    function test_eventCompoundFieldsAndLinkCreation() {
        const record=item("event","event");const s=start([record]);open(s);
        edit(s,"agendaField::event.location","Studio",Qt.Key_Return);
        compare(mutations()[0].params.patch.event.people[0],"Alex");compare(mutations()[0].params.patch.event.status,"confirmed");
        const location=item("event","event",2);location.event.location="Studio";success(s,location);
        edit(s,"agendaField::event.people","Alex\nSam",Qt.Key_Return);
        compare(mutations()[1].params.patch.event.people.length,2);compare(mutations()[1].params.patch.event.location,"Studio");
        const people=item("event","event",3);people.event={location:"Studio",people:["Alex","Sam"],status:"confirmed"};success(s,people,3);
        s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);clickRevealed(s,"agendaAddLink");
        tryCompare(s.owner,"collectionOpen",true);const modal=field(s,"agendaCollectionDialog");
        tryVerify(()=>findChild(modal,"promptInput").inputActiveFocus);wait(0);
        findChild(modal,"promptInput").focusInput(true);typeText("Documentation");
        findChild(modal,"agendaNewLinkUrl").focusInput(true);typeText("https://example.org/docs");
        compare(mutations().length,2);mouseClick(findChild(modal,"detailAction:accept"));compare(mutations().length,3);
        const link=mutations()[2].params.patch.links[0];verify(link.id.length>0);compare(link.label,"Documentation");compare(link.url,"https://example.org/docs");
        finish(s,null,"Submitted link failed");verify(s.owner.collectionOpen);
        compare(findChild(modal,"agendaNewLinkUrl").text,"https://example.org/docs");
        mouseClick(findChild(modal,"detailAction:accept"));compare(mutations().length,4);compare(mutations()[3].params.patch.links.length,1);compare(mutations()[3].params.patch.links[0].id,link.id);
        const linked=JSON.parse(JSON.stringify(people));linked.revision=4;linked.links=[link];success(s,linked,4);
        tryVerify(()=>findChild(s.view,"agendaLinkUrl::"+link.id)!==null);
    }
    function test_checklistInsertionReorderingAndRemovalKeepIdentityAndParent() {
        const s=start();open(s);s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);
        clickRevealed(s,"agendaStepUp::step2");compare(mutations().length,1);
        const reordered=mutations()[0].params.patch.task;compare(reordered.checklist[0].id,"step2");compare(reordered.checklist[0].checked,true);compare(reordered.completed,false);
        const record=item("a","task",2);record.task=reordered;success(s,record);
        clickRevealed(s,"agendaAddStep");const modal=field(s,"agendaCollectionDialog");
        tryVerify(()=>findChild(modal,"promptInput").inputActiveFocus);wait(0);
        findChild(modal,"promptInput").focusInput(true);typeText("Third independent step");mouseClick(findChild(modal,"detailAction:accept"));
        compare(mutations().length,2);const added=mutations()[1].params.patch.task.checklist[2];verify(added.id!=="step1"&&added.id!=="step2");compare(added.checked,false);compare(added.text,"Third independent step");
        const withStep=item("a","task",3);withStep.task=mutations()[1].params.patch.task;success(s,withStep,3);
        clickRevealed(s,"agendaRemoveStep::step1");compare(mutations().length,3);
        compare(mutations()[2].params.patch.task.checklist.length,2);verify(!mutations()[2].params.patch.task.checklist.some(step=>step.id==="step1"));compare(mutations()[2].params.patch.task.completed,false);
    }
    function test_lazySummaryDetailsAndMalformedMutationTarget() {
        const full=item("lazy");
        const s=start([Agenda.AgendaRepository.summaryOf(full)]);
        compare(Object.keys(Agenda.AgendaRepository.records).length,0);
        open(s);tryVerify(()=>calls.some(call=>call.method==="agenda.get"));
        compare(findChild(s.view,"agendaNotes"),null,"omitted fields are not fabricated as empty editors");
        const get=calls.filter(call=>call.method==="agenda.get").slice(-1)[0];
        respond(get,{item:full,catalog_revision:1});
        tryVerify(()=>findChild(s.view,"agendaTitle")!==null);
        edit(s,"agendaTitle","Explicit",Qt.Key_Return);compare(mutations().length,1);
        const wrong=item("wrong","task",2);
        finish(s,{request_id:s.owner.operation.request_id,item:wrong,catalog_revision:2});
        compare(s.owner.selectedItem.id,"lazy");verify(s.owner.failedOperation!==null);verify(!Agenda.AgendaRepository.records.wrong);
    }
    function test_page51RefreshIsAtomicAndPreservesNativeDraft() {
        const first=[];for(let index=0;index<50;index++) first.push(item("row"+index));
        const s=start(first);accept(s.owner,first,1,"page2");
        s.owner.receiveList({generation:s.owner.readGeneration,query:"",day:"",epoch:Agenda.AgendaRepository.epoch,append:true,cursor:"page2"},windowData([item("row50")],1),"");
        compare(s.owner.items.length,51);s.owner.selectionModel.selectedIndex=50;open(s);
        const title=edit(s,"agendaTitle","Still draft");
        s.owner.refresh();wait(150);
        let root=calls.filter(call=>call.method==="agenda.list"&&!call.params.cursor).slice(-1)[0];
        const page=first.map(value=>Agenda.AgendaRepository.summaryOf(Object.assign({},value,{revision:2})));
        respond(root,windowData(page,2,"refresh2"));
        compare(s.owner.items.length,51);compare(s.owner.selectedItem.id,"row50");compare(title.text,"Still draft");
        let continuation=calls.filter(call=>call.method==="agenda.list"&&call.params.cursor==="refresh2").slice(-1)[0];
        respond(continuation,null,"Page failed");compare(s.owner.items.length,51);compare(title.text,"Still draft");
        s.owner.refresh();wait(150);root=calls.filter(call=>call.method==="agenda.list"&&!call.params.cursor).slice(-1)[0];respond(root,windowData(page,2,"refresh2"));
        continuation=calls.filter(call=>call.method==="agenda.list"&&call.params.cursor==="refresh2").slice(-1)[0];
        const updated=item("row50","task",2);updated.title="Backend51";
        respond(continuation,windowData([Agenda.AgendaRepository.summaryOf(updated)],2));
        const get=calls.filter(call=>call.method==="agenda.get").slice(-1)[0];verify(get!==undefined);respond(get,{item:updated,catalog_revision:2});
        compare(s.owner.items.length,51);compare(field(s,"agendaTitle"),title);compare(title.text,"Still draft");
        compare(mutations().length,0);keyClick(Qt.Key_Escape);tryCompare(title,"text","Backend51");
    }
    function chooseOption(s,name) {
        const control=field(s,name);mouseClick(control);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(0);
    }
    function test_timedCreationKeepsRawOffsetAndZoneAndCancelsLateParser() {
        const s=start([]);s.view.listItem.focusSearch();keyClick(Qt.Key_A,Qt.AltModifier);
        const modal=field(s,"agendaCreateDialog");
        compare(field(s,"agendaCreateKind").value,"task");chooseOption(s,"agendaCreateKind");compare(s.owner.createDraft.kind,"event");
        compare(field(s,"agendaScheduleMode").value,"date");chooseOption(s,"agendaScheduleMode");
        field(s,"agendaScheduleStart").focusInput(true);typeText("2026-03-29T02:30:00+01:00");
        field(s,"agendaScheduleZone").focusInput(true);typeText("Europe/Amsterdam");
        findChild(modal,"promptInput").focusInput(true);typeText("DST example");
        mouseClick(findChild(modal,"detailAction:accept"));
        const parse=calls.filter(call=>call.method==="agenda.schedule").slice(-1)[0];
        compare(parse.params.mode,"timed");compare(parse.params.start_text,"2026-03-29T02:30:00+01:00");compare(parse.params.timezone,"Europe/Amsterdam");compare(mutations().length,0);
        parsed(null,"Local time is in a DST gap");compare(field(s,"agendaScheduleStart").text,"2026-03-29T02:30:00+01:00");capture(s,"agenda-timed-validation");
        field(s,"agendaScheduleStart").focusInput(true);keySequence("Ctrl+A");typeText("2026-03-29T03:30:00+02:00");
        mouseClick(findChild(modal,"detailAction:accept"));verify(s.owner.scheduleParsing);
        keyClick(Qt.Key_Escape);tryCompare(s.owner,"createOpen",false);
        parsed({mode:"timed",start_date:null,end_date:null,start_unix_ms:1774747800000,end_unix_ms:null,timezone:"Europe/Amsterdam"});
        compare(mutations().length,0,"late validation cannot create after cancellation");
    }
    function test_existingTimedEndpointIsPreservedAsFactNotReparsedOrInferred() {
        const record=item("timed","event");record.schedule={mode:"timed",start_date:null,end_date:null,start_unix_ms:1774747800000,end_unix_ms:null,timezone:"Europe/Amsterdam"};
        const s=start([record]);open(s);s.view.listItem.focusList();keyClick(Qt.Key_E,Qt.AltModifier);
        const modal=field(s,"agendaScheduleDialog");
        compare(field(s,"agendaScheduleStart").text,"2026-03-29T01:30:00.000Z");
        field(s,"agendaScheduleEnd").focusInput(true);typeText("2026-03-29T04:30:00+02:00");mouseClick(findChild(modal,"detailAction:accept"));
        const parse=calls.filter(call=>call.method==="agenda.schedule").slice(-1)[0];compare(parse.params.start_text,"");compare(parse.params.end_text,"2026-03-29T04:30:00+02:00");
        parsed({mode:"timed",start_date:null,end_date:null,start_unix_ms:null,end_unix_ms:1774751400000,timezone:"Europe/Amsterdam"});
        compare(mutations().length,1);compare(mutations()[0].params.patch.schedule.start_unix_ms,1774747800000);compare(mutations()[0].params.patch.schedule.end_unix_ms,1774751400000);
        const saved=JSON.parse(JSON.stringify(record));saved.revision=2;saved.schedule=mutations()[0].params.patch.schedule;success(s,saved);
        s.view.listItem.focusList();keyClick(Qt.Key_E,Qt.AltModifier);
        field(s,"agendaScheduleStart").focusInput(true);keySequence("Ctrl+A");keyClick(Qt.Key_Backspace);mouseClick(findChild(modal,"detailAction:accept"));
        parsed({mode:"timed",start_date:null,end_date:null,start_unix_ms:null,end_unix_ms:null,timezone:"Europe/Amsterdam"});
        compare(mutations().length,2);compare(mutations()[1].params.patch.schedule.start_unix_ms,null);compare(mutations()[1].params.patch.schedule.end_unix_ms,1774751400000,"unchanged stored end stays a fact, never inferred");
    }
    function test_unsupportedWidthBlocksNativePrimaryAndRetainsEditorDraft() {
        const s=start();s.owner.availableScreenWidth=400;tryCompare(s.view,"supported",false);verify(s.owner.navigation.blocked);
        s.view.listItem.focusList();keyClick(Qt.Key_Return);compare(mutations().length,0);
        s.owner.availableScreenWidth=1280;open(s);const title=edit(s,"agendaTitle","Retained draft");
        s.owner.availableScreenWidth=400;keyClick(Qt.Key_Return);compare(mutations().length,0);compare(title.text,"Retained draft");
        s.owner.availableScreenWidth=1280;compare(field(s,"agendaTitle"),title);compare(title.text,"Retained draft");keyClick(Qt.Key_Escape);tryCompare(title,"text","Item a");
    }
    function test_standaloneTitleOnlyAndNarrowLayoutGuard() {
        const s=start([]);s.view.listItem.focusSearch();keyClick(Qt.Key_A,Qt.AltModifier);
        const modal=field(s,"agendaCreateDialog");tryVerify(()=>findChild(modal,"promptInput").inputActiveFocus);wait(0);
        typeText("Title only");mouseClick(findChild(modal,"detailAction:accept"));compare(mutations().length,1);
        compare(mutations()[0].params.item.title,"Title only");compare(mutations()[0].params.item.schedule.start_date,null);compare(mutations()[0].params.item.schedule.end_date,null);
        success(s,item("title-only"));
        s.owner.availableScreenWidth=400;tryCompare(s.view,"supported",false);verify(!s.view.navigationEnabled);verify(!s.owner.geometry.horizontalOverflowAllowed);
    }
    function test_atomicScheduleDraftFailureClearAndReopen() {
        const s=start();open(s);s.view.listItem.focusList();keyClick(Qt.Key_E,Qt.AltModifier);
        tryCompare(s.owner,"scheduleOpen",true);
        const modal=field(s,"agendaScheduleDialog");
        const startField=field(s,"agendaScheduleStart");startField.focusInput(true);typeText("2026-12-02");
        const endField=field(s,"agendaScheduleEnd");endField.focusInput(true);typeText("2026-11-01");
        compare(mutations().length,0,"modal fields remain local until Save");
        mouseClick(findChild(modal,"detailAction:accept"));compare(mutations().length,0);
        parsed(null,"Reversed dates");verify(s.owner.scheduleOpen);compare(startField.text,"2026-12-02");
        endField.focusInput(true);keySequence("Ctrl+A");keyClick(Qt.Key_Backspace);typeText("2026-12-03");
        mouseClick(findChild(modal,"detailAction:accept"));compare(mutations().length,0);
        const scheduled=item("a","task",2);scheduled.schedule.start_date="2026-12-02";scheduled.schedule.end_date="2026-12-03";
        parsed(scheduled.schedule);compare(mutations().length,1);
        compare(mutations()[0].params.patch.schedule.start_date,"2026-12-02");compare(mutations()[0].params.patch.schedule.end_date,"2026-12-03");
        success(s,scheduled);
        verify(!s.owner.scheduleOpen);
        s.view.listItem.focusList();keyClick(Qt.Key_E,Qt.AltModifier);tryCompare(s.owner,"scheduleOpen",true);
        tryCompare(field(s,"agendaScheduleStart"),"text","2026-12-02");
        keyClick(Qt.Key_Escape);compare(mutations().length,1);
    }
    function test_readOnlyAndMalformedWindowFailClosed() {
        const record=item("imported","event");record.capabilities={write:false,delete:false,complete:false};
        const s=start([record]);open(s);
        verify(field(s,"agendaTitle").readOnly);s.view.listItem.focusList();keyClick(Qt.Key_D,Qt.AltModifier);keyClick(Qt.Key_E,Qt.AltModifier);
        verify(!s.owner.modalOpen);compare(mutations().length,0);
        const malformed=item("bad");malformed.task.checklist.push({id:"step1",text:"Duplicate identity",checked:true});
        accept(s.owner,[malformed],2);compare(s.owner.items[0].id,"imported");verify(s.owner.error.length>0);
    }
    function test_notesDraftSurvivesKeyedChecklistArrivalAndStatusCompoundPatch() {
        const s=start();open(s);s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);
        const step=edit(s,"agendaStep::step1","Unsubmitted");
        const record=item("a","task",2);record.task.checklist.push({id:"step3",text:"Arrived",checked:false});
        Agenda.AgendaRepository.accept(record,2);
        compare(field(s,"agendaStep::step1"),step);compare(step.text,"Unsubmitted");compare(mutations().length,0);
        keyClick(Qt.Key_Escape);tryCompare(step,"text","First");
        edit(s,"agendaNotes","Saved notes",Qt.Key_Return);compare(mutations().length,1);compare(mutations()[0].params.patch.notes,"Saved notes");
        const saved=item("a","task",3);saved.notes="Saved notes";success(s,saved,3);
        s.owner.setDetailsTab("details");tryVerify(()=>findChild(s.view,"agendaField::task.status")!==null);
        edit(s,"agendaField::task.status","in-progress",Qt.Key_Return);
        const patch=mutations()[1].params.patch.task;compare(patch.status,"in-progress");compare(patch.priority,3);compare(patch.checklist.length,2);compare(patch.completed,false);
    }
    function test_nativePrimaryAndActionFreeInspection() {
        const s=start();
        const row=field(s,"agendaRow::a");mouseClick(row,80,row.height/2);
        compare(mutations().length,0);compare(s.owner.detailsOpen,false);
        open(s);compare(mutations().length,0);
        s.view.listItem.focusList();keyClick(Qt.Key_Return);
        compare(mutations().length,1);compare(mutations()[0].params.patch.task.completed,true);
        compare(s.owner.items[0].task.completed,false,"no optimistic acknowledgement");
        const record=item("a","task",2);record.task.completed=true;record.task.completed_unix_ms=7;
        success(s,record);
        compare(s.owner.items[0].id,"a");compare(s.owner.items[0].task.completed,true);
        compare(s.owner.selectedItem.task.checklist[0].checked,false);
        mouseDoubleClickSequence(row,80,row.height/2);compare(mutations().length,2);compare(mutations()[1].params.patch.task.completed,false);compare(mutations()[1].params.patch.task.completed_unix_ms,null);
        s.owner.selectionModel.selectedIndex=1;s.view.listItem.focusList();keyClick(Qt.Key_Return);
        compare(mutations().length,2);verify(s.owner.detailsOpen);
    }
    function test_titleEnterEscapeTabAndIncomingRevision() {
        const s=start();open(s);
        const title=edit(s,"agendaTitle","Draft");
        compare(mutations().length,0);
        const record=item("a","task",2);record.title="Incoming";
        Agenda.AgendaRepository.accept(record,2);
        compare(title.text,"Draft");keyClick(Qt.Key_Escape);
        tryCompare(title,"text","Incoming");compare(mutations().length,0);
        edit(s,"agendaTitle","Saved",Qt.Key_Return);
        compare(mutations().length,1);compare(mutations()[0].params.patch.title,"Saved");
        compare(mutations()[0].params.expected_revision,2);
        finish(s,null,"Conflict");compare(s.owner.valueFor(s.owner.selectedItem,"title",""),"Saved");
        s.owner.refresh();wait(150);compare(mutations().length,1,"refresh never retries mutation");
        s.view.listItem.focusList();keyClick(Qt.Key_R,Qt.AltModifier);
        const currentRead=calls.filter(call=>call.method==="agenda.get").slice(-1)[0];verify(currentRead!==undefined);
        respond(currentRead,{item:record,catalog_revision:2});
        tryVerify(()=>s.owner.rebaseTarget!==null);
        mouseClick(findChild(field(s,"agendaRebaseDialog"),"detailAction:accept"));compare(mutations().length,2);
        const saved=item("a","task",3);saved.title="Saved";success(s,saved,3);
        compare(s.owner.failedDraft,null);
        edit(s,"agendaTitle","Tabbed",Qt.Key_Tab);compare(mutations().length,3);
    }
    function test_staleWindowsRetainedAndIndependentScopes() {
        const s=start();const other=createTemporaryObject(ownerFactory,testCase,{uiActive:true,dayScope:"2026-10-28"});
        accept(other,[item("b","event")]);
        const old=s.owner.readGeneration;s.owner.filterText="next";
        compare(s.owner.items[0].id,"a");
        s.owner.receiveList({generation:old,query:"",day:"",epoch:Agenda.AgendaRepository.epoch,append:false},windowData([item("wrong")]),"");
        compare(s.owner.items[0].id,"a");
        s.owner.receiveList({generation:s.owner.readGeneration,query:"next",day:"",epoch:Agenda.AgendaRepository.epoch,append:false},null,"Read failed");
        compare(s.owner.items.length,2);compare(other.filterText,"");compare(other.dayScope,"2026-10-28");
        accept(s.owner,[item("b","event"),item("a")],2,"native-cursor");
        compare(s.owner.items[0].id,"b","native supplied order only");
        s.owner.loadMore();tryVerify(()=>calls.some(call=>call.method==="agenda.list"&&call.params.cursor==="native-cursor"));
        const record=item("b","event",3);record.title="Shared accepted";Agenda.AgendaRepository.accept(record,3);
        compare(s.owner.items[0].title,"Shared accepted");compare(other.items[0].title,"Shared accepted");
    }
    function test_sharedCreationDayDefaultsAndOutsideScopeInspector() {
        const s=start([]);s.owner.dayScope="2026-10-27";s.view.listItem.focusSearch();
        keyClick(Qt.Key_A,Qt.AltModifier);tryCompare(s.owner,"createOpen",true);
        compare(s.owner.createDraft.schedule.start_date,"2026-10-27");compare(s.owner.createDraft.schedule.end_date,"2026-10-27");capture(s,"agenda-creation-context");
        const modal=field(s,"agendaCreateDialog");
        field(s,"agendaScheduleStart").focusInput(true);keySequence("Ctrl+A");keyClick(Qt.Key_Backspace);
        field(s,"agendaScheduleEnd").focusInput(true);keySequence("Ctrl+A");keyClick(Qt.Key_Backspace);
        field(s,"promptInput").focusInput(true);typeText("New item");
        keyClick(Qt.Key_Tab,Qt.ControlModifier);compare(s.owner.detailsTab,"details","modal blocks tab command");
        mouseClick(findChild(modal,"detailAction:accept"));
        parsed(s.owner.emptySchedule());
        compare(mutations().length,1);compare(mutations()[0].params.item.schedule.start_date,null);compare(mutations()[0].params.item.title,"New item");
        finish(s,null,"Validation failed");verify(s.owner.createOpen);compare(s.owner.createDraft.title,"New item");
        mouseClick(findChild(modal,"detailAction:accept"));parsed(s.owner.emptySchedule());compare(mutations().length,2);
        const record=item("created");record.title="New item";success(s,record);
        compare(s.owner.items.length,0,"creation outside day never inserts a false scoped row");
        compare(s.owner.selectedItem.id,"created");verify(s.owner.detailsOpen);
    }
    function test_threeTabsChecklistIndependentAndConfirmedDelete() {
        const s=start();open(s);
        s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);tryCompare(s.owner,"detailsTab","notes");
        tryVerify(()=>findChild(s.view,"agendaNotes")!==null);
        const checked=field(s,"agendaStepChecked::step1");mouseClick(checked);
        compare(mutations().length,1);const patch=mutations()[0].params.patch;
        compare(patch.task.completed,false);compare(patch.task.checklist[0].id,"step1");compare(patch.task.checklist[0].checked,true);
        const record=item("a","task",2);record.task.checklist[0].checked=true;success(s,record);
        s.view.listItem.focusList();keyClick(Qt.Key_Tab,Qt.ControlModifier);compare(s.owner.detailsTab,"information");
        keyClick(Qt.Key_D,Qt.AltModifier);tryVerify(()=>s.owner.deleteTarget!==null);compare(mutations().length,1);
        keyClick(Qt.Key_Escape);compare(s.owner.deleteTarget,null);compare(mutations().length,1);
        s.view.listItem.focusList();keyClick(Qt.Key_D,Qt.AltModifier);
        const modal=field(s,"agendaDeleteDialog");mouseClick(findChild(modal,"detailAction:accept"));
        compare(mutations().length,2);compare(s.owner.items.length,2);
        finish(s,{request_id:s.owner.operation.request_id,item:null,catalog_revision:3,deleted_id:"a"});
        compare(s.owner.items.length,1);
    }
}
