import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: tests
    name: "NotificationCache"
    width: 1100; height: 700; visible: true; when: windowShown
    Component { id: stateFactory; Activity.NotificationState {} }
    Component { id: catalogFactory; Activity.NotificationCatalog {} }
    Component { id: timelineFactory; Activity.NotificationTimeline {} }
    Component { id: controllerFactory; Activity.NotificationController {} }
    Component { id: contentFactory; Activity.NotificationContent {} }
    function init() { calls=[]; clientReady=true; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Unable to assign).*/); }
    function state() {
        const value=createTemporaryObject(stateFactory,tests,{uiActive:true});
        value.applySummary({available:true,backend:"native",history_revision:1,app_policies:{}});
        return value;
    }
    function make(kind) {
        const store=state();
        const reader=createTemporaryObject(kind==="apps"?catalogFactory:timelineFactory,store,{store:store,active:true});
        if(kind==="timeline") { reader.appKey="named:Chat"; reader.requestedDate="older"; }
        reload(reader,kind);
        return {store:store,reader:reader,kind:kind};
    }
    function reload(reader,kind) { if(kind==="apps") reader.reloadApps(); else reader.reload(); }
    function rows(s) { return s.kind==="apps"?s.reader.apps:s.reader.entries; }
    function busy(s) { return s.kind==="apps"?s.reader.rootBusy:s.reader.busy; }
    function error(s) { return s.kind==="apps"?s.reader.rootError:s.reader.error; }
    function pending(s) {
        const requests=s.store.backend.requests;
        const generation=s.kind==="apps"?s.reader.rootGeneration:s.reader.generation;
        const id=Object.keys(requests).find(id=>requests[id].center?.view===s.kind && requests[id].center.generation===generation);
        verify(!!id,"owned "+s.kind+" request");
        return {id:id,context:requests[id].center};
    }
    function preview(i,app) { const id=10000-i; return {id:id,created_unix_ms:id*1000,app_key:app,app_name:app,app_icon:"",summary:"Message "+i,body:"Body"}; }
    function page(s,offset,size,reached) {
        const length=Math.min(size,805-offset),next=offset+length<805?offset+length:null;
        const value={view:s.kind,query:s.reader.query,epoch:"epoch",revision:"rev",offset:offset,next_offset:next,anchor_reached:reached};
        if(s.kind==="apps") {
            value.total_apps=805;
            value.apps=Array.from({length:length},(_,i)=>({key:"named:app-"+(offset+i),count:1,total_count:1,latest:preview(offset+i,"named:app-"+(offset+i))}));
        } else {
            Object.assign(value,{app_key:"named:Chat",date:"older",period_day:"2026-10-29",recent:[],
                dates:["today","week","month","older"].map(key=>({key:key,count:key==="older"?805:0})),count:805,total_rows:805,
                entries:Array.from({length:length},(_,i)=>{const p=preview(offset+i,"named:Chat");return {key:p.id+":"+p.created_unix_ms,preview:p,members:[{id:p.id,created:p.created_unix_ms}]};})});
        }
        return value;
    }
    function reply(s,value,failure,code) { s.store.backend.finish(pending(s).id,{notification_center:value},failure||"",code||""); }
    function fill(s) {
        const size=s.kind==="apps"?50:20;
        while(!s.reader.cacheFull) {
            if(!busy(s)) s.reader.loadMore();
            const offset=pending(s).context.offset;
            reply(s,page(s,offset,size,true));
        }
        compare(rows(s).length,200);
    }
    function test_boundedBrowseRefreshAndClose_data() { return [{tag:"apps",kind:"apps"},{tag:"timeline",kind:"timeline"}]; }
    function test_boundedBrowseRefreshAndClose(data) {
        const s=make(data.kind),size=data.kind==="apps"?50:20;
        fill(s);
        const before=calls.length;s.reader.autoLoadMore();compare(calls.length,before,"automatic reads stop at the cap");
        const seen=rows(s).map(row=>row.key);
        while(s.reader.hasMore) {
            const replacing=s.reader.cacheFull;
            s.reader.loadMore();const offset=pending(s).context.offset;
            reply(s,page(s,offset,size,true));
            verify(rows(s).length<=200);verify((s.reader.staging?.entries||s.reader.staging||[]).length<=200);
            seen.push(...rows(s).slice(replacing?0:-Math.min(size,805-offset)).map(row=>row.key));
        }
        compare(seen.length,805);compare(new Set(seen).size,805);
        compare(s.reader.windowOffset,800);
        reload(s.reader,s.kind);compare(pending(s).context.offset,800,"older refresh does not scan the prefix");
        reply(s,page(s,800,size,true));compare(rows(s).length,5);
        s.reader.showRecent();compare(pending(s).context.offset,0);reply(s,page(s,0,size,true));compare(rows(s).length,size);
        fill(s);reload(s.reader,s.kind);
        const old=pending(s).context;
        s.reader.active=false;compare(rows(s).length,0);compare(s.reader.windowOffset,0);
        compare(s.kind==="apps"?s.reader.nextOffset:s.reader.snapshot.next_offset, s.kind==="apps"?null:undefined);
        compare((s.reader.staging?.entries||s.reader.staging||[]).length,0);
        s.reader.receive(old,page(s,0,size,true),"","");compare(rows(s).length,0);
        s.reader.active=true;reload(s.reader,s.kind);
        compare(pending(s).context.offset,0);reply(s,page(s,0,size,true));compare(rows(s).length,size);
        verify(!busy(s));verify(!error(s));s.reader.active=false;
    }
    function test_refreshAndStaleRetriesAreBounded_data() { return test_boundedBrowseRefreshAndClose_data(); }
    function test_refreshAndStaleRetriesAreBounded(data) {
        const s=make(data.kind),size=data.kind==="apps"?50:20;fill(s);
        reload(s.reader,s.kind);
        for(let offset=0;offset<200;offset+=size) {
            compare(pending(s).context.offset,offset);
            reply(s,page(s,offset,size,false));
            compare(rows(s).length,200,"replacement is atomic");
        }
        verify(!busy(s));compare(rows(s).length,200,"missing old anchor cannot grow the cache");
        s.reader.loadMore();reply(s,null,"Read failed","");compare(rows(s).length,200);compare(s.reader.windowOffset,0);
        s.reader.showRecent();reply(s,page(s,0,size,true));fill(s);
        s.reader.loadMore();reply(s,page(s,200,size,true));compare(s.reader.windowOffset,200);
        reload(s.reader,s.kind);compare(pending(s).context.offset,200);
        reply(s,null,"Stale","history-cursor-stale");compare(rows(s).length,size);
        reload(s.reader,s.kind);compare(pending(s).context.offset,0);
        reply(s,page(s,0,size,true));compare(s.reader.windowOffset,0);compare(rows(s).length,size);
        reload(s.reader,s.kind);reply(s,null,"Stale","history-cursor-stale");
        reload(s.reader,s.kind);reply(s,null,"Still stale","history-cursor-stale");
        verify(error(s).length>0);verify(!busy(s));
        const count=calls.length;wait(160);compare(calls.length,count,"stale reset retries only once");
        s.reader.active=false;
    }
    function test_shortAndMalformedPagesNeverOverflow_data() { return test_boundedBrowseRefreshAndClose_data(); }
    function test_shortAndMalformedPagesNeverOverflow(data) {
        const s=make(data.kind),size=data.kind==="apps"?50:20;
        reply(s,page(s,0,13,true));
        while(!s.reader.cacheFull) {s.reader.loadMore();const offset=pending(s).context.offset;reply(s,page(s,offset,size,true));}
        const retained=rows(s).length;verify(retained<=200);verify(retained+size>200);
        const count=calls.length;s.reader.autoLoadMore();compare(calls.length,count);
        s.reader.loadMore();compare(pending(s).context.offset,retained);
        reply(s,page(s,retained,size+1,true));verify(error(s).length>0);compare(rows(s).length,retained);
        s.reader.active=false;
    }
    function test_exactAppLookupScansWithoutKeepingItsPrefix() {
        const s=make("apps");reply(s,page(s,0,50,true));
        reload(s.reader,s.kind);const obsolete=pending(s).context;
        s.reader.revealKey="named:app-804";reload(s.reader,s.kind);
        s.reader.receive(obsolete,page(s,0,50,true),"","");compare(s.reader.apps.length,50);verify(s.reader.rootBusy);
        for(let offset=0;offset<805;offset+=50) {
            compare(pending(s).context.offset,offset);reply(s,page(s,offset,50,offset>=800));
            verify(s.reader.staging.length<=200);verify(s.reader.apps.length<=200);
        }
        compare(s.reader.windowOffset,800);verify(s.reader.apps.some(app=>app.key==="named:app-804"));
        compare(s.reader.revealKey,"");s.reader.active=false;
    }
    function test_nativeBoundaryCommandsAndControllerCacheRelease() {
        const store=state();const owner=createTemporaryObject(controllerFactory,store,{notificationState:store,uiActive:true});
        const apps={store:store,reader:owner.catalog,kind:"apps"};owner.catalog.reloadApps();fill(apps);owner.rebuildRecords();
        const view=createTemporaryObject(contentFactory,owner,{controller:owner,width:width,height:height});
        view.listItem.focusList();wait(30);keyClick(Qt.Key_M,Qt.AltModifier);
        compare(pending(apps).context.offset,200);reply(apps,page(apps,200,50,true));wait(0);
        view.listItem.focusList();keyClick(Qt.Key_F,Qt.AltModifier);
        compare(pending(apps).context.offset,0);reply(apps,page(apps,0,50,true));wait(0);
        owner.catalog.nextOffset=null;owner.catalog.apps=[{key:"named:Chat",latest:preview(0,"named:Chat"),count:805,total_count:805}];owner.rebuildRecords();
        owner.detailsOpen=true;owner.timeline.requestedDate="older";
        const history={store:store,reader:owner.timeline,kind:"timeline"};owner.timeline.reload();fill(history);
        tryVerify(()=>view.detailsNavigation.contentReady);view.listItem.focusList();wait(30);keyClick(Qt.Key_L,Qt.AltModifier);
        compare(pending(history).context.offset,200);reply(history,page(history,200,20,true));wait(0);
        view.listItem.focusList();keyClick(Qt.Key_B,Qt.AltModifier);
        compare(pending(history).context.offset,0);reply(history,page(history,0,20,true));wait(30);
        compare(owner.timeline.entries.length,20,"latest does not refill from an old scroll anchor");
        owner.deactivateUi();compare(owner.notificationModel.count,0);compare(owner.visibleApps.length,0);
        compare(owner.catalog.apps.length,0);compare(owner.timeline.entries.length,0);compare(Object.keys(owner.appViews).length,0);
        verify(!calls.some(call=>["notifications.delete","notifications.setAppPolicy"].includes(call.method)));
        view.destroy();
    }
}
