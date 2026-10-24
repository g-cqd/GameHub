#!/bin/bash
# Functional checks of the MacFontCache on the throwaway prefix (clone runtime hub-0-fontperf).
W=/Volumes/ExT2/GameHub/work/wine-fontperf/bin/w
C=/Volumes/ExT2/GameHub/work/wine-fontperf/prefix/drive_c
cd /tmp
t(){ WD=+pid,trace+font $W "$@" 2>&1 | grep -E "font files from|changed|^magic|^dir |bumped" | sed "s/trace:font://"; }
echo "-- delete value, then GDI exe (expect CoreText in the first process, cache in the second)"
t 'C:\modcache.exe' del; t 'C:\fontenum.exe' min
echo "-- stored list"; t 'C:\modcache.exe'
echo "-- bump stamp, then GDI exe (expect changed + CoreText, then cache)"
t 'C:\modcache.exe' stamp >/dev/null; t 'C:\fontenum.exe' min
echo "-- corrupt value via reg.exe (its own lazy font init must reject it and rewrite)"
t reg add 'HKCU\Software\Wine\Fonts\MacFontCache' /v Files /t REG_BINARY /d 4d574643deadbeef /f
echo "-- cache disabled (expect CoreText in both processes)"
EXTRA_ENV=WINE_MAC_FONT_CACHE=0 t 'C:\fontenum.exe' min
echo "-- enumeration identity: R (runtime original), N (cache off), C (cache on)"
rm -f $C/enum-*.txt
RT=/Volumes/ExT2/GameHub/work/wine-fontperf/rt-base $W 'C:\fontenum.exe' list 'C:\enum-R.txt' >/dev/null 2>&1
EXTRA_ENV=WINE_MAC_FONT_CACHE=0 $W 'C:\fontenum.exe' list 'C:\enum-N.txt' >/dev/null 2>&1
$W 'C:\fontenum.exe' list 'C:\enum-C.txt' >/dev/null 2>&1
wc -l $C/enum-R.txt $C/enum-N.txt $C/enum-C.txt
cmp $C/enum-R.txt $C/enum-N.txt && cmp $C/enum-R.txt $C/enum-C.txt && echo "ENUM IDENTICAL (R = N = C)"
