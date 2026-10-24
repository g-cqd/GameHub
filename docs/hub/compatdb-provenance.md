# compatdb.so and external binary provenance

Checked 2026-10-15. "Verified" means checked in this session; "unverified"
means not checked or not determinable from the sources available.

## Summary

- The runtime's `compatdb.so` comes from https://github.com/athei/wine-build
  (crate `compatdb/`, docs `docs/compatdb.md`), per the task background and the
  repo README. Its sha256 does **not** match any `compatdb.so` in the 13
  published releases (see below). How the runtime copy was produced is
  unverified.
- athei/wine-build has no licence. Its source must not be vendored.
- Three other binaries in the runtime come from local repos (x87sidecar, DXMT,
  mtld3d). None has a recorded pinned build; reproducibility is unknown for all.

## compatdb.so (runtime copy)

| Field | Value |
|-------|-------|
| Path | `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-unix/compatdb.so` |
| Size | 357792 bytes |
| sha256 | `c79c4aede8444e561dba6df221b35822037e213963103770f3fad288b92230cb` |
| Architecture | Mach-O 64-bit, x86_64 only (thin) |
| Code signature | Developer ID Application: Guillaume Coquard (NP94WB3P75), identifier `compatdb`, hardened runtime flag set |
| Loaded by | Wine ntdll, `<ntdll_dir>/compatdb.so`, dlopen'd in every process; reads env var `WINE_COMPATDB` |

### Key list

Verified against the "Settings" table in `docs/compatdb.md` (191 lines, fetched
with `gh api`): `dxgi`, `d3d9`, `dll_overrides`, `dpi_aware`,
`large_address_aware`, `x87_sidecar`, `arguments`, `env`. This matches the
task's list.

The task's list omits keys that are not settings but are part of the format:
`exe` (a match key), `name` (required), `enabled`, and the match keys
`company`, `product`, `original_filename`.

### Release match

Method: `gh release list` and `gh api .../tags` (13 releases, 13 tags, none
drafts). For each `cx-*` release, `gh release download -p
'wine-<tag>-macos-x86_64.tar.xz'`, `tar -xJf ... wine/lib/wine/x86_64-unix/compatdb.so`
(only that member), then `shasum -a 256`. Tarballs were deleted afterwards.

| Release | compatdb.so sha256 | Match |
|---------|--------------------|-------|
| cx-26.3.0-9 | `5c5b0dd3c12994a53492467146d91143e0c5a7f70229afafa1d8cba5b7720347` | no |
| cx-26.3.0-8 | `ac889c04eaa9364e297858eb313c6ea3919a0314115c851e0b2b22543d65a9c9` | no |
| cx-26.3.0-7 | `23b89728dc6207408945ad0ceef5ba272a510145a0d7708f54e52f9b369a640e` | no |
| cx-26.3.0-6 | same as cx-26.3.0-7 | no |
| cx-26.3.0-5 | `a9a7a04c88bbf4b710aa2b26b4abdc6d478c8422aeb92fba0bd8391aa59001b2` | no |
| cx-26.3.0-4 | same as cx-26.3.0-5 | no |
| cx-26.3.0-3 | `a4e319168a13bbf27c37b3a2792160233f934f47ead5e9d5b53adf9b753fa877` | no |
| cx-26.3.0-2, -1, -0, cx-26.2.0-0 | no `compatdb.so` in the tarball | n/a |

- Not inspected: `deps-2026-09-06` (its tarball listing contains no
  `compatdb` entry) and `gptk-4.0-beta-2` (Apple dmg mirror).
- **Result: no match found among releases cx-26.2.0-0 through cx-26.3.0-9.**
- The README (`/athei/wine-build` `README.md`, "Getting a build") says
  `compatdb-*` releases exist, containing `compatdb.so` rebuilt from a tag.
  None are published (no `compatdb-*` tag or release at check time). Whether
  the runtime copy came from one of those, a local build, or an unpublished
  commit is unverified.
- The release tarball itself was checked: `cx-26.3.0-9` tarball sha256
  `af3682051414eeffa5be48584a671790fd3852e980ff5acd38facff6f4bff1e9` matches the
  GitHub asset digest.

### Licence

- `gh repo view athei/wine-build --json licenseInfo` returns `licenseInfo: null`.
- The repo root has no `LICENSE`, `COPYING` or `NOTICE` file. `compatdb/Cargo.toml`
  and the root `Cargo.toml` have no `license` field.
- Conclusion: the licence is unspecified. Do not vendor the source or
  redistribute the binary. Ask the author for a licence, or ask for permission
  to reproduce the build.
- Forking does not solve this. A fork carries the same absent licence and does
  not grant anyone a licence to use or redistribute the code. The author's
  Developer ID signature is not a licence either.

## Other external binaries the runtime depends on

| Component | Source repo | Local checkout (HEAD, state) | Runtime path | sha256 | Reproducible from pinned commit |
|-----------|-------------|------------------------------|--------------|--------|----------------------------------|
| x87sidecar | `https://github.com/g-cqd/x87sidecar` (origin only; `LICENSE` is MIT, Copyright 2025 Lifeisawful) | `/Users/gc/Developer/x87sidecar`, `62679aa`, **3 modified files uncommitted** | `/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar` (616272 bytes; `start-ea.sh` default via `HUB_X87_PATH`) | `0cc5ea16e3547942666f8133cdd3e2abd82e3311ddbd3b03d1a3170072247a42` | unknown (no pinned commit; dirty checkout; not verified that this binary came from this checkout) |
| DXMT | `https://github.com/g-cqd/dxmt` (origin only; `LICENSE` is LGPL-2.1, Copyright 2023-2026 Feifan He for CodeWeavers). Task names upstream `3Shain/dxmt`, but no `upstream` remote is configured locally, so unverified | `/Users/gc/Developer/dxmt`, `447815b`, clean | `.../hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/dxgi/dxmt/` (see below) | see below | unknown |
| mtld3d | `https://github.com/g-cqd/mtld3d` (fork; `UPSTREAM.md` says it tracks athei/mtld3d; no `upstream` remote configured locally, so unverified). `LICENSE`: Copyright 2026 Alexander Theissen, "as-is" warranty disclaimer | `/Users/gc/Developer/mtld3d`, `cd53057`, clean | `.../hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/d3d9/mtld3d/` (see below) | see below | unknown |

Runtime root below: `RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer`.

DXMT (`$RT/lib/wine/dxgi/dxmt/`):

| File | sha256 |
|------|--------|
| `x86_64-unix/winemetal.so` (identical to `winemetal.so.orig-2217`) | `f75c4327e749dcc97665853e89fec480dd24cc19c6dd69bdd6b2ae12296971c4` |
| `x86_64-windows/d3d11.dll` | `62e79c3517977d59c2696d7124f20ed1ba5412064cd93ac94d0a993bbf2d3a52` |
| `x86_64-windows/dxgi.dll` | `fc58aae0aba511a1ec4d2417e5bba6adb888bb14315d0f59cccdfd27f670d544` |
| `x86_64-windows/winemetal.dll` | `514245d533c750599614311a792c45ed600aef52948571d98c0fc70fd3df16e0` |
| `i386-windows/d3d11.dll` | `e85d5fdc00f23f53bd022e1f83a5c7783dbcaacc53e410af59b18e690f98f900` |
| `i386-windows/dxgi.dll` | `7df8cdf66e12a108410002abc77b01f70aa59b8a36a70fa0bc6ae3b056841319` |

- Sibling files `*.orig-rtv`, `*.orig-staging`, `*.orig-2217` exist next to
  several DLLs (e.g. `x86_64-windows/d3d11.dll.orig-rtv`,
  `4b41f97f9b1b560f52f685d4198c2c00db91bc6a032560da08a0e5180bbbd948`). They
  suggest locally patched DLLs (the runtime name says "dxmtrtv"). Patch origin:
  unverified.
- Top-level `$RT/lib/wine/x86_64-windows/{d3d9,d3d11,dxgi,mtld3d}.dll` and the
  `i386-windows` equivalents also exist; their origin is unverified.

mtld3d (`$RT/lib/wine/d3d9/mtld3d/`):

| File | sha256 |
|------|--------|
| `x86_64-unix/mtld3d.so` | `90eaa3eba0786c5cbd474f3ea0226d8c61c6f82d2adeb2c9167489000aa41198` |
| `x86_64-windows/d3d9.dll` | `6474af800c48d724f3f4868606b308395ae457ecd68160d7dd2d9d44103395eb` |
| `x86_64-windows/mtld3d.dll` | `5ec9f25c30ed1b5633eef3c9c3dc5e79c44c1447f7975946a089c712d6a1ef33` |
| `i386-windows/d3d9.dll` | `daeb5f40f07ccf901a07947b44f5caac6206adeb8022058c7b90257e6d6bf4fd` |
| `i386-windows/mtld3d.dll` | `19ae5c0a90dba32c8faf1543c80e521737677b3401499282a090e26af27d24cd` |

## How to re-verify

```sh
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer

# compatdb.so: hash, size, arch, signature
shasum -a 256 "$RT/lib/wine/x86_64-unix/compatdb.so"
stat -f%z "$RT/lib/wine/x86_64-unix/compatdb.so"
file "$RT/lib/wine/x86_64-unix/compatdb.so"
lipo -archs "$RT/lib/wine/x86_64-unix/compatdb.so"
codesign -dvv "$RT/lib/wine/x86_64-unix/compatdb.so"

# x87sidecar
shasum -a 256 /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar

# DXMT and mtld3d trees
find "$RT/lib/wine/dxgi/dxmt" "$RT/lib/wine/d3d9/mtld3d" -type f -exec shasum -a 256 {} +

# Release comparison (one tag; repeat per cx-* tag)
D=$(mktemp -d)
gh release download cx-26.3.0-9 -R athei/wine-build -p 'wine-cx-26.3.0-9-macos-x86_64.tar.xz' -D "$D"
tar -xJf "$D/wine-cx-26.3.0-9-macos-x86_64.tar.xz" -C "$D" wine/lib/wine/x86_64-unix/compatdb.so
shasum -a 256 "$D/wine/lib/wine/x86_64-unix/compatdb.so"
rm -rf "$D"

# Source repo state
git -C /Users/gc/Developer/x87sidecar rev-parse HEAD && git -C /Users/gc/Developer/x87sidecar status --short
git -C /Users/gc/Developer/dxmt rev-parse HEAD && git -C /Users/gc/Developer/dxmt status --short
git -C /Users/gc/Developer/mtld3d rev-parse HEAD && git -C /Users/gc/Developer/mtld3d status --short

# Upstream docs (read-only)
gh api repos/athei/wine-build/contents/docs/compatdb.md --jq .content | base64 -d
gh release list -R athei/wine-build --limit 30
```
