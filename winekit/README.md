# WineKit

Parts of Wine rewritten in Swift, one boundary at a time (GameHub ADR-0020, roadmap 0035).

| Target | What it is |
|---|---|
| `HubRules` | The runtime rules of `dlls/ntdll/unix/hubrules.c`: rules parsing, predicates, PE header facts. Embedded-Swift clean, so it can link into Wine's x86_64 Unix side with libc only. |
| `hubrules-swift` | A host tool printing what `hub_rules_apply` would do, for the differential test. |
| `QualityKit`, `winekit-quality`, `Quality` plugin | The quality gates, in Swift and tested. |

## Gates

```sh
WINEKIT_DEV=1 swift package --allow-network-connections all:443 --allow-writing-to-package-directory quality all
WINEKIT_DEV=1 swift package --disable-sandbox quality mutation          # minutes; runs SwiftPM itself
WINEKIT_DEV=1 swift package --disable-sandbox quality changed pre-commit
```

| Request | What runs |
|---|---|
| `config`, `manifest`, `tags` | Aemi's canonical `.swift-format`/`.swiftlint.yml`, `check-manifest-settings.sh`, `check-tags.sh` |
| `format`, `lint` | swift-format lint --strict; SwiftLint size and complexity metrics |
| `analyzers` | deadwood, dolly, arcleak, fcheck, modeler, at the versions Aemi's `scripts/analyzers.lock` pins |
| `test` | the suites in debug, then release |
| `embedded` | `HubRules` as Embedded Swift for `x86_64-apple-macos15`; only libc symbols may stay undefined |
| `differential` | Wine's `hubrules.c` (from `WINE_SRC`, default `~/Developer/wine`) against `hubrules-swift` over `Differential/` |
| `mutation` | swift-mutation-testing over the libraries; no survivor outside `docs/mutation-baseline.md`, score ≥ 90 |
| `fast` / `all` | the static gates / everything but mutation |
| `changed pre-commit\|pre-push` | every gate scoped to the change: format and lint read the changed files, the analyzers report only them, mutation mutates only the changed library sources |

`WINEKIT_DEV=1` resolves Aemi (Aemi-Studio/aemi, pinned in `Package.swift`): its LintBuild plugin, scripts, lock and
configuration. swift-mutation-testing, which Aemi doesn't pin, is pinned in `Quality/tools.lock`. Every download is
checked against its pinned SHA-256 and the binary's reported version before it runs.

GameHub's `.project-hooks.yml` runs `quality changed` on commit and push once the repository is trusted
(`git config project-hooks.trusted true`).
