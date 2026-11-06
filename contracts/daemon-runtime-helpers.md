# Runtime helper ownership

## Generic result ranking

`daemon-framework/crates/shelllist-search` owns normalization, fuzzy/typo matching
and the existing score/provider-priority/title/key ordering. `bar-daemon` executes
that matcher through its ordinary v2 D-Bus and Unix JSONL service. Shelllist no
longer ships or starts a `shelllist-search` worker.

- `search.catalog({owner, revision, items})` replaces one ephemeral catalog. The
  positive revision must increase; an identical retransmission is idempotent. Catalog names are scoped to the physical
  transport caller, never trusted as authorization across clients.
- `search.query({owner, revision, generation, query})` returns the matching owner,
  revision, generation and ordered keys. An absent or mismatched catalog rejects
  the read rather than ranking another client's data or a stale catalog.
- `search.release({owner})` idempotently removes that caller's catalog. Connection
  loss clears all its catalogs, including resources admitted during disconnect.

Each client has at most 128 catalogs and a bounded retained catalog budget;
individual catalogs contain at most 20,000 items. At most 64 clients and two
blocking ranking jobs are admitted. Capacity rejection never dispatches a domain
effect. Search text is not persisted or broadcast.

Shelllist debounces/coalesces the latest query per view, waits for a catalog
acknowledgement before querying its revision and rejects stale replies. Queries
are serialized per view; releasing a view waits for any in-flight catalog/query
before sending release. A reconnect restores only live catalogs and their latest
queries, including empty queries. The last accepted result window remains visible
while ranking is pending. Native provider-ranked windows bypass this API.

This changes no field navigation, save/discard transaction, domain acknowledgement
or primary action. `tst_search_service.qml` covers actual Qt completion/reconnect
behavior; chooser keyboard/memory tests retain interaction and stable-selection
coverage. Native service tests exercise private Unix sockets for isolation,
revision guards, release and disconnect cleanup, and the existing socket/D-Bus
parity test exercises all three methods through the production dispatch path.

UI asset generation, `xtask` and the external performance lens remain in Shelllist.
Their presence does not create a runtime Rust service in the UI repository.

## Portal execution

`nm-daemon/src/bin/nm-portal-launch.rs` now supplies the native browser/workspace
executor as `nm-portal-launch` in the NM package. Shelllist no longer builds or
ships a separate Rust portal package. The graphical UI invokes the executable
with the acknowledged intent's URL/deadline and its explicit workspace intent.
It still performs prepare, verifies the owned claim and immutable intent, executes
once and reports `opened`, `failed` or `uncertain` through complete. Only the NM
service owns network identity, claim admission, fallback and durable deduplication.

This is package/source ownership consolidation: the executor remains a short-lived
graphical effect adapter, preserving the caller's compositor/browser environment.
It does not add a daemon or change the portal RPC contract. Its fixed window class,
private runtime profile, nonblocking lock, URL/workspace validation and deadline
checks are preserved. Missing output, crashes and interruption remain uncertain;
neither reconnect nor an unknown result automatically repeats the effect.

Native executable argument/compositor tests now live in the NM package. Actual
Qt `tst_wifi_portal.qml` verifies that only an acknowledged claim invokes the
NM-packaged command with the exact URL, workspace and deadline, alongside Alt+I,
no launch on navigation, stale/changed claims, transport loss and outcome handling.
