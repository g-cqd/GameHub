# WineKit

Parts of Wine rewritten in Swift, one boundary at a time (GameHub ADR-0020, roadmap 0035).

| Path | What it is |
|---|---|
| `Sources/HubRules` | The runtime rules of Wine's ntdll (parsing, predicates, PE header facts), Embedded-Swift clean. Wine's `dlls/ntdll/unix/hubrules.c` calls it through `C/winekit.h` (wine b9f9755bb12). |
| `C/winekit.h` | The C interface Wine includes. |
| `Sources/QualityKit`, `Sources/winekit-quality`, `Plugins/` | The quality gates and the Wine build artifacts, in Swift and tested: `swift package quality …`, `swift package wine-objects …`. |
| `Differential/` | The differential corpus, and `reference/hubrules.c`: the C implementation as it was before WineKit, the reference Wine's build is compared with. |

## For Wine

```sh
swift package --disable-sandbox wine-objects --output /Volumes/ExT2/GameHub/build/winekit   # libwinekit.a, winekit.h
make WINEKIT_DIR=/Volumes/ExT2/GameHub/build/winekit                                         # in Wine's build tree
```

Wine's `build-macos-x86_64.sh make` does both. The archive holds Embedded Swift objects for `x86_64-apple-macos15`
that need libc only and define every symbol `winekit.h` declares; the `embedded` gate checks both.

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
| `differential` | `Differential/reference/hubrules.c` against Wine's `hubrules.c` (from `WINE_SRC`, default `~/Developer/wine`) with `libwinekit.a`: the same stdout and stderr over `Differential/` |
| `mutation` | swift-mutation-testing over the code Wine runs (HubRules), on the efficiency cores (`taskpolicy -b`, one worker per E-core); score ≥ 90 and no survivor outside `docs/mutation-baseline.md` |
| `fast` / `all` | the static gates / everything but mutation |
| `changed pre-commit\|pre-push` | every gate scoped to the change: format and lint read the changed files, the analyzers report only them; a push also mutates the changed HubRules sources (a commit doesn't wait for it) |

Aemi (Aemi-Studio/aemi, pinned in `Package.swift`) is a regular dependency: QualityKit builds on AemiFileSystem, and the
gates use Aemi's scripts, analyzers lock and configuration. HubRules doesn't use it, because it links into ntdll as Embedded
Swift and AemiKernel isn't Embedded-clean yet (`../development/reports/aemi-embedded-kernel.md`). `WINEKIT_DEV=1` adds
Aemi's LintBuild plugin to every build; Wine's build leaves it out. Resolving Aemi also fetches swift-syntax,
swift-collections and swift-system, including for Wine's `wine-objects` step. swift-mutation-testing, which Aemi doesn't pin, is pinned in `Quality/tools.lock`. Every download is
checked against its pinned SHA-256 and the binary's reported version before it runs.

GameHub's `.project-hooks.yml` runs `quality changed` on commit and push once the repository is trusted
(`git config project-hooks.trusted true`).
