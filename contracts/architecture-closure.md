# Architecture closure evidence

## Step 1 — current product integration

`local-build check shelllist --offline --keep-going` passed on x86_64-linux.
This captures current sibling sources, not deployed binaries. All five daemon
package/contract checks, framework checks, generated fixtures/bindings, QML lint,
TypeScript freshness and native QML passed. Nix reused matching successful
check outputs where available. Native QML: **651 passed, 0 failed, 1 existing
software-renderer skip**. Logs: `/tmp/shelllist-closure/step1{,-qml}.log`.

Sources at capture:

| Repository | Commit |
| --- | --- |
| daemon-framework | 1e023d12ed8facc30259a0ad5609e418b1a55d9a |
| app-daemon | 7afc66ab7e4406a57ac820f21aa8e5a75095db19 |
| bar-daemon | 4dfb44d5dc7693a0de0bb5c2adc0f597107385c0 |
| bt-daemon | 994fc5e48fd2bf9393d239136debefd3bafef92c |
| clip-daemon | ba2163baf539df2f789c3976479a61a013a1d553 |
| nm-daemon | c9f37c1c7cff5a5db8eaa88f6424ae843678590d |
| update-daemon | 3f05cf1bccdb280685e4a500b0b901fa055ef237 |
| shelllist | d13234e15153976f21cdcb1b1d29362010fe5d44 |

The older HTML ledger predates the coordinated v2 cutover. Current code already
uses v2 envelopes in all five daemons and a shared direct-bus boundary. Complete
typed method coverage and metadata-driven service policy remain separate gaps.
This gate proves packaged/isolated integration, not live hardware, compositor or
privileged update deployment. No live service was restarted.
