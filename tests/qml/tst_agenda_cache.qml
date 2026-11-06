import QtQuick
import Shelllist.Activity as Agenda
import Shelllist.Io as Io

DaemonTestCase {
    id: tests
    name: "AgendaCache"
    width: 1100; height: 700; visible: true; when: windowShown
    Component { id: ownerFactory; Agenda.AgendaController {} }
    Component { id: viewFactory; Agenda.AgendaContent {} }
    function init() {
        calls=[];clientReady=true;
        Agenda.AgendaRepository.records=({});Agenda.AgendaRepository.catalogRevision=-1;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Unable to assign).*/);
    }
    function item(i) {
        return {id:"item-"+i,kind:"task",source_id:"local",source_uid:null,revision:1,title:"Item "+i,notes:"Notes",links:[],
            schedule:{mode:"date",start_date:null,end_date:null,start_unix_ms:null,end_unix_ms:null,timezone:null},
            created_unix_ms:1,modified_unix_ms:2,capabilities:{write:true,delete:true,complete:true},event:null,
            task:{priority:3,status:"needs-action",completed:false,completed_unix_ms:null,checklist:[]}};
    }
    function page(offset,count,revision) {
        const length=Math.min(count,805-offset);
        return {items:Array.from({length:length},(_,i)=>Agenda.AgendaRepository.summaryOf(item(offset+i))),
            next_cursor:offset+length<805?"opaque/"+(offset+length):null,catalog_revision:revision||1,today:"2026-10-29",timezone:"Europe/Amsterdam"};
    }
    function make() { const owner=createTemporaryObject(ownerFactory,tests,{uiActive:true});tryCompare(owner,"loading",true);return owner; }
    function request(owner,purpose) {
        const requests=Agenda.AgendaRepository.requests;
        const id=Object.keys(requests).find(id=>requests[id].owner===owner.ownerId&&requests[id].purpose===(purpose||"list"));
        verify(!!id,"owned "+(purpose||"list")+" request");return {id:id,context:requests[id].context};
    }
    function respond(id,data,error) {
        const session=Io.DaemonSessions.sessions["bar-activity-daemon"];
        const call=calls.find(call=>call.route?.localId===id);verify(!!call);
        session.client.response(call.id,{protocol:"bar-api",version:2,ok:!error,data:data,error:error?{code:"fixture",message:error}:undefined},"",call.route);
    }
    // Fixture-server cursor decoding only. Production must replay issued tokens.
    function offset(context) { return context.cursor?Number(context.cursor.slice(7)):0; }
    function next(owner,count) {
        const call=request(owner),value=page(offset(call.context),count||50);
        respond(call.id,value);return value;
    }
    function fill(owner) {
        while(!owner.cacheFull) {if(!owner.loading) owner.loadMore();next(owner);}
        compare(owner.items.length,200);
    }
    function refresh(owner) { owner.refresh();tryCompare(owner,"loading",true); }
    function test_all805ItemsBoundedRefreshAndReopen() {
        const owner=make(),seen=[];
        while(owner.loading||owner.nextCursor) {
            if(!owner.loading) {
                if(owner.cacheFull) {const count=calls.length;owner.autoLoadMore();compare(calls.length,count);}
                owner.loadMore();
            }
            const value=next(owner);seen.push(...value.items.map(item=>item.id));
            verify(owner.items.length<=200);verify(owner.itemModel.count<=200);
            for(const pending of Object.values(Agenda.AgendaRepository.requests).filter(value=>value.owner===owner.ownerId&&value.purpose==="list")) verify(pending.context.staging.length<=200);
        }
        compare(seen.length,805);compare(new Set(seen).size,805);compare(owner.windowOffset,800);
        compare(owner.windowStartCursor,"opaque/800");
        refresh(owner);compare(request(owner).context.cursor,"opaque/800");next(owner);compare(owner.items.length,5);
        owner.showFirst();compare(request(owner).context.cursor,"");next(owner);compare(owner.items.length,50);
        fill(owner);refresh(owner);const first=request(owner);next(owner);
        const staged=request(owner);compare(staged.context.staging.length,50);compare(owner.items.length,200);
        owner.deactivateUi();compare(owner.items.length,0);compare(owner.itemModel.count,0);
        compare(owner.nextCursor,"");compare(owner.windowStartCursor,"");compare(owner.windowOffset,0);verify(!owner.acceptedWindow);
        compare(Object.values(Agenda.AgendaRepository.requests).filter(value=>value.owner===owner.ownerId&&["list","get"].includes(value.purpose)).length,0);
        respond(staged.id,page(50,50));respond(first.id,page(0,50));compare(owner.items.length,0);
        owner.activateUi("");tryCompare(owner,"loading",true);compare(request(owner).context.cursor,"");next(owner);
        compare(owner.items.length,50);verify(!owner.loading);owner.deactivateUi();
    }
    function test_shortPagesErrorsAndLateScopesRetainAcceptedWindow() {
        const owner=make();next(owner,13);
        while(!owner.cacheFull) {owner.loadMore();next(owner);}
        const count=owner.items.length;verify(count<=200);verify(count+50>200);
        owner.loadMore();const replacement=request(owner);compare(replacement.context.cursor,"opaque/"+count);
        respond(replacement.id,null,"Read failed");compare(owner.items.length,count);compare(owner.windowOffset,0);
        owner.showFirst();next(owner);fill(owner);
        const context={generation:owner.readGeneration,query:"",day:"",epoch:Agenda.AgendaRepository.epoch,append:true,cursor:owner.nextCursor};
        owner.receiveList(context,page(200,50),"");compare(owner.items.length,200);verify(owner.error.length>0);
        owner.showFirst();const obsolete=request(owner);owner.filterText="work";tryCompare(owner,"loading",true);
        compare(request(owner).context.cursor,"");compare(request(owner).context.query,"work");
        respond(obsolete.id,page(0,50));compare(owner.items.length,200);verify(owner.loading);next(owner);compare(owner.items.length,50);
        owner.dayScope="2026-10-30";tryCompare(owner,"loading",true);compare(request(owner).context.cursor,"");
        compare(request(owner).context.day,"2026-10-30");next(owner);
        owner.loadMore();const empty=page(50,0);empty.next_cursor="different-token";respond(request(owner).id,empty);
        verify(owner.error.length>0);compare(owner.items.length,50);verify(!owner.loading);owner.deactivateUi();
    }
    function test_olderStaleCursorKeepsInspectedDraftUntilExplicitFirstCommand() {
        const owner=make();fill(owner);owner.loadMore();next(owner);compare(owner.windowOffset,200);
        const full=item(200);Agenda.AgendaRepository.accept(full,1);owner.detailItem=full;owner.detailsOpen=true;
        const view=createTemporaryObject(viewFactory,owner,{controller:owner,width:width,height:height});
        tryVerify(()=>view.detailsNavigation.contentReady);const title=findChild(view,"agendaTitle");verify(!!title);
        tryVerify(()=>view.detailsNavigation.targets.indexOf(title)>=0);
        title.focusInput(true);keySequence("Ctrl+A");keyClick("x");compare(title.text,"x");
        refresh(owner);compare(request(owner).context.cursor,"opaque/200");
        respond(request(owner).id,null,"stale agenda cursor; restart query");
        compare(owner.items.length,50);compare(owner.selectedItem.id,"item-200");compare(findChild(view,"agendaTitle"),title);compare(title.text,"x");
        const count=calls.length;wait(160);compare(calls.length,count,"no prefix scan or automatic stale retry");
        view.listItem.focusList();keyClick(Qt.Key_F,Qt.AltModifier);
        compare(request(owner).context.cursor,"");next(owner);compare(owner.windowOffset,0);compare(owner.items.length,50);
        verify(!calls.some(call=>call.method==="agenda.patch"),"explicit navigation discarded, never saved, the field buffer");
        owner.deactivateUi();view.destroy();
    }
    function test_boundaryCommandsAndClosePreserveSubmittedDraftAndWriteOwnership() {
        const owner=make();fill(owner);
        const view=createTemporaryObject(viewFactory,owner,{controller:owner,width:width,height:height});
        view.listItem.focusList();wait(30);keyClick(Qt.Key_M,Qt.AltModifier);
        compare(request(owner).context.cursor,"opaque/200");next(owner);compare(owner.windowOffset,200);
        const full=item(200);owner.detailItem=full;owner.saveFieldFor(full,"title","Submitted");
        const write=request(owner,"mutation"),operation=owner.operation;
        owner.showFirst();verify(!owner.loading,"explicit boundary cannot evict a pending write");
        owner.deactivateUi();compare(owner.items.length,0);compare(owner.itemModel.count,0);
        compare(owner.detailItem.id,"item-200");compare(owner.savedDrafts["item-200:title"].value,"Submitted");
        verify(!!Agenda.AgendaRepository.requests[write.id]);compare(owner.operation.request_id,operation.request_id);
        respond(write.id,null,"Uncertain write");compare(owner.failedOperation.request_id,operation.request_id);
        compare(owner.savedDrafts["item-200:title"].value,"Submitted");
        owner.activateUi("");tryCompare(owner,"loading",true);next(owner);
        compare(owner.items.length,50);compare(owner.savedDrafts["item-200:title"].value,"Submitted");
        compare(calls.filter(call=>call.method==="agenda.patch").length,1,"close/reopen never replays a write");
        owner.deactivateUi();view.destroy();
    }
}
