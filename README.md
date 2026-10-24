# GameHub

Run Windows games on Apple Silicon Macs through one Wine prefix, one runtime and the stores' own launchers (Steam, EA app,
Ubisoft Connect, Epic Games Launcher). The runtime is a Wine fork with Metal renderers (DXMT for Direct3D 10/11, mtld3d for
Direct3D 8/9) and an x87 sidecar for 32-bit games under Rosetta.

This is an experimental project. Game installations, Wine prefixes, saves, store accounts and Apple runtime binaries are
external inputs and are not in this repository. Game data and the runtime live on an external volume (`HUB_ROOT`, default
`/Volumes/ExT2/GameHub`).

## Use it

```sh
launcher/hub list                       # discovered games, their launcher, and whether each is known to work
launcher/hub play <game>                # e.g. aoa, bf3, nfs, gtav: starts the launcher, then the game
launcher/hub start steam|ea|ubisoft|epic
launcher/hub status | stop | doctor
launcher/hub play <game> --metalfx 1.5  # DXMT MetalFX spatial upscaling (factor above 1.0, at most 2.0)
```

See [`launcher/README.md`](launcher/README.md) for the layout of the volume, the options and why each fix is there.

## Layout

| Path | What it is |
|---|---|
| `launcher/` | `hub`, the single command (Python, standard library only), and the known-good game settings in `settings/` |
| `runtime/` | `hub-rules.txt`: per-program rules (renderer backend, environment, arguments) shipped inside the runtime |
| `scripts/` | Runtime assembly (`assemble_runtime.sh`), media bundling, mtld3d install, and `check_links.py` for the docs |
| `toolchains/` | `provision.sh`: the build toolchains (Rust, MSVC headers, llvm-mingw, Wine SDK) on the external volume |
| `apps/bundler/` | Swift package: native starters and signed, notarized bundles for Need for Speed, Call of Duty 4, Far Cry 2 and Battlefield 3, plus the GameHub app and `gamehub-cli` |
| `docs/` | Documentation; start at [`docs/README.md`](docs/README.md) |
| `research/` | Scripts from the EA anti-cheat investigation |
| `archive/` | Finished work kept for reference |

## Documentation entry points

- How the hub works and how to restart it: [`docs/hub/`](docs/hub/)
- Renderer, x87 sidecar and Wine SDK knowledge: [`docs/knowledge/`](docs/knowledge/)
- Bundler, per-game notes, licensing and source offer: [`apps/bundler/docs/`](apps/bundler/docs/)
- Reverse-engineering policy for this repository: [`REVERSE-ENGINEERING.md`](REVERSE-ENGINEERING.md)

## Licenses

Each component keeps its own license; see [`apps/bundler/NOTICE`](apps/bundler/NOTICE),
[`apps/bundler/THIRD_PARTY.md`](apps/bundler/THIRD_PARTY.md) and [`apps/bundler/Licenses/`](apps/bundler/Licenses/).
The bundler's source offer for the Wine builds it ships is in [`apps/bundler/docs/SOURCE-OFFER.md`](apps/bundler/docs/SOURCE-OFFER.md).
