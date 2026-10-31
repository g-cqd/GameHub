#!/bin/bash
# Run a command (default: wine ARGS) under a GameHub runtime with the standard session environment.
#   HUB_RUNTIME   runtime dir        (default hub-1)
#   HUB_PREFIX    wine prefix        (default ~/Games/SteamLight/prefix)
#   HUB_WINEDEBUG WINEDEBUG          (default -all)
#   HUB_LOG       log file           (default: stdout)
# Sidecar: bin/x87sidecar next to bin/wine is picked up by Wine for every 32-bit process.
H=/Volumes/ExT2/GameHub
L=$HOME/Games/SteamLight
RT=${HUB_RUNTIME:-$( [ -x "$L/runtime/bin/wine" ] && echo "$L/runtime" || echo "$H/Runtimes/hub-1" )}
PFX=${HUB_PREFIX:-$HOME/Games/SteamLight/prefix}
# HUB_GAME_DXGI: graphics backend for the game executables (dxmt | wined3d); default dxmt
GD=${HUB_GAME_DXGI:-dxmt}
COMPAT="v=3
name=steam-webhelper;exe=steamwebhelper.exe;dxgi=dxmt
name=aoa;exe=ActOfAggressionRE.exe;dxgi=$GD
name=aoa2;exe=ActOfAggression.exe;dxgi=$GD
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt"
mkdir -p "$PFX" "$HOME/Games/SteamLight/tmp" "$HOME/Games/SteamLight/home"
exec env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player \
  HOME="$HOME/Games/SteamLight/home" TMPDIR="$HOME/Games/SteamLight/tmp" \
  WINEPREFIX="$PFX" WINEDLLOVERRIDES="mscoree,mshtml=d;winemenubuilder.exe=d" WINEDEBUG="${HUB_WINEDEBUG:--all}" WINEMSYNC="${HUB_MSYNC:-1}" \
  DYLD_FALLBACK_LIBRARY_PATH="$RT/lib/external:$RT/lib/external/media:$RT/lib/external/vulkan" VK_ICD_FILENAMES="$RT/lib/external/vulkan/MoltenVK_icd.json" \
  GST_PLUGIN_SYSTEM_PATH_1_0="$RT/lib/external/media/plugins" GST_PLUGIN_PATH_1_0="$RT/lib/external/media/plugins" \
  GST_REGISTRY_1_0="$HOME/Games/SteamLight/tmp/gst-registry.bin" GST_REGISTRY_FORK=no \
  WINE_COMPATDB="$COMPAT" "${@:-$RT/bin/wine}"
