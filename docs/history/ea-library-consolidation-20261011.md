# EA library consolidation, stage S0 survey and mapping (2026-10-11)

Written by stage S0 at 2026-10-11T16:59:28Z. S0 is read-only: nothing under the prefix, the game folders or the runtimes was modified. Only this file and `ea-library-consolidation-20261011.log` were written. Scratch helpers (read-only scanners) live in `/tmp/s0/` and can be deleted at will.

Notation: `P` = `/Volumes/ExT2/GameHub/Prefix`, `G` = `/Volumes/ExT2/GameHub`. Wine drive map (read from `P/dosdevices`): `c:` -> `../drive_c`, `e:` -> `/Volumes/ExT2/GameHub` (= `G`), `z:` -> `/`. Wine user profile: `P/drive_c/users/crossover`.

State at survey time: no wineserver or wine process for `P` is running. The only wine processes belong to wineserver pid 93725 with `WINEPREFIX=/Volumes/ExT2/GameHub/work/wine-gepperf-tools/prefix` (another job: wineserver -p, services.exe, PnkBstrA.exe, EABackgroundService.exe standin, explorer, keepdesk). `lsof +D P` shows only the survey shell itself. The registry hives were last written at 18:48:18 local and were hashed (see section 5) so a later stage can detect any drift.

---

## (a) Move table

| # | Game | Unix old | Unix new | Windows old | Windows new |
|---|---|---|---|---|---|
| M1 | Battlefield 4 | `G/EA Games/BF4/Battlefield 4` | `G/EA Games/Battlefield 4` | `E:\EA Games\BF4\Battlefield 4` | `E:\EA Games\Battlefield 4` |
| M2 | Crysis 3 | `G/EA Games/BF4/Crysis 3` | `G/EA Games/Crysis 3` | `E:\EA Games\BF4\Crysis 3` | `E:\EA Games\Crysis 3` |
| M3 | F1 24 | `G/EA Games/BF4/F1 24` | `G/EA Games/F1 24` | `E:\EA Games\BF4\F1 24` | `E:\EA Games\F1 24` |
| M4 | (cleanup) | `G/EA Games/BF4` (must be empty except Finder `.DS_Store`; currently holds `.DS_Store` 6148 B) | removed | `E:\EA Games\BF4` | gone |
| M5 | Battlefield 3 | `P/drive_c/Program Files/EA Games/Battlefield 3` | `G/EA Games/Battlefield 3` | `C:\Program Files\EA Games\Battlefield 3` | `E:\EA Games\Battlefield 3` |
| M6 | Need for Speed | already `G/EA Games/Need for Speed` (`E:\EA Games\Need for Speed`) | no move | | |
| M7 | NFS hard-link mirror | `G/Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed` | removed (S3) | `C:\Program Files\EA Games\Need for Speed` (old NFS wrapper prefix only) | gone |
| M8 | EA Desktop ini | `user.downloadinplacedir=E:\EA Games\BF4\` | `user.downloadinplacedir=E:\EA Games\` | | |

Targets `G/EA Games/{Battlefield 4,Crysis 3,F1 24,Battlefield 3}` do not exist today (checked). `G/EA Games` currently contains only `BF4/`, `Need for Speed/` and a `.DS_Store`. `G/Library/EA` is a relative symlink `../EA Games` and stays valid.

After M1..M3, `G/EA Games/BF4` still contains a Finder `.DS_Store` (6148 B, 2026-10-11 18:23); a later stage must delete it (it is not game data) before `rmdir`. There are also 6 + 4 + 31 `.DS_Store` files inside the BF4 / Crysis 3 / F1 24 folders (counted in the baselines below).

---

## (b) Exact string mapping

### b.0 Registry file format (how Wine escapes)

- All three hives (`system.reg`, `user.reg`, `userdef.reg`): `file(1)` = "WINE registry text, version 2"; **UTF-8 without BOM**; **LF line endings** (`grep -c $'\r'` = 0 in all three); line counts 114539 / 3524 / 64.
- Header lines: `WINE REGISTRY Version 2`, blank, `;; All keys relative to REGISTRY\\Machine` (system.reg) or `;; All keys relative to REGISTRY\\User\\S-1-5-21-0-0-0-1000` (user.reg) or `...\\User\\.Default` (userdef.reg), blank, `#arch=win64`, blank.
- Key header: `[Software\\Wow6432Node\\EA Games\\Battlefield 4] 1791660146` (every path separator doubled; space + unix seconds), next line `#time=<hex FILETIME>`. Empty intermediate keys (no values, only subkeys) appear to be omitted, so a nested path shows up only as one long header.
- Value line: `"Name"="text"`; default value `@="text"`. Inside text: backslash -> `\\`, double quote -> `\"`, non-ASCII -> `\xNNNN` (e.g. `Battlefield 4\x2122`). REG_EXPAND_SZ is `"Name"=str(2):"text"`, REG_MULTI_SZ `str(7):"a\0b\0"`; DWORD `dword:0000000e`; binary `hex:aa,bb,\` with continuation lines indented by two spaces; `hex(2)`, `hex(7)` for UTF-16LE hex-encoded strings. **No hex-encoded (UTF-16) value in any of the three hives contains an old path** (all values were decoded and searched; the only `hex:` false positives were certificate blobs).
- Because the hives are plain text with no length fields, a literal substring replace on the raw text is safe (string length may change). Replace only while no wine process uses `P`; Wine rewrites all three files on shutdown.
- Example of the stored form of a value with embedded quotes: `"DisplayIcon"="\"E:\\EA Games\\BF4\\Battlefield 4\\BFLauncher_x86.exe\""`.

### b.1 The only literal rules (case-sensitive, applied to the raw hive text; verified: every hit line contains exactly one occurrence and every hit has the trailing `\\`)

| Rule | Stage | Old literal (as stored in .reg) | New literal (as stored) | system.reg lines | user.reg lines |
|---|---|---|---|---|---|
| R-BF4 | S2 | `EA Games\\BF4\\` (always preceded by `E:\\`; i.e. `E:\\EA Games\\BF4\\`) | `EA Games\\` (i.e. `E:\\EA Games\\`) | 113 values | 2 key-name headers |
| R-BF3 | S4 | `C:\\Program Files\\EA Games\\Battlefield 3\\` | `E:\\EA Games\\Battlefield 3\\` | 8 values | 4 key-name headers |
| R-NFS | S3 | none: the shared prefix has no record naming `C:\Program Files\EA Games\Need for Speed` (its only NFS record is `E:\\EA Games\\Need for Speed\\`, already final) | | 0 | 0 |

Per-game breakdown of R-BF4 in system.reg: F1 24 = 95 (18 MSI speech/prereq products x [SourceList `LastUsedSource`, `SourceList\\Net` values `1` and `2`, `UserData\\S-1-5-18\\Products\\<code>\\InstallProperties` `InstallSource`] = 72, plus 18 `Uninstall\\{GUID}` `InstallSource` values (17 under Wow6432Node, 1 under native `Software\\Microsoft\\...\\Uninstall\\{3B433087-...}`), plus 2 `Codemasters\\F1_24` `Install Dir`, plus Uninstall `{12151659-5588-4775-BEB0-34E053E23212}` `DisplayIcon`/`HelpLink`/`InstallLocation` = 3), Battlefield 4 = 12, Crysis 3 = 5, PunkBuster Services uninstall key = 1 (points into the BF4 folder). R-BF3 in system.reg: GameUX `{A15F8AC8-...}` 2, `Wow6432Node\\EA Games\\Battlefield 3` 2, Uninstall `{76285C16-411A-488A-BCE3-C83CB933D8CF}` 4 (`DisplayIcon`, `HelpLink`, `InstallLocation`, `Readme`).

**Do NOT rewrite** (they must stay as they are): `C:\\Program Files (x86)\\Common Files\\EAInstaller\\{Battlefield 3,Battlefield 4,Crysis 3}\\Cleanup.exe` and `C:\\Program Files\\Common Files\\EAInstaller\\F1_24\\Cleanup.exe` (EA's uninstaller helpers, not moved), `C:\\Program Files (x86)\\Battlelog Web Plugins\\...`, `C:\\Program Files\\EA\\AC\\...`, `Software\\Wow6432Node\\EA Games\\Need for Speed` `Install Dir` (already `E:\\EA Games\\Need for Speed\\`).

Expected post-edit counts (for the verifier), system.reg: `grep -c -F 'EA Games\\BF4'` = 0; `grep -c -F 'Program Files\\EA Games\\Battlefield 3'` = 0; occurrences of `E:\\EA Games\\` = 122 (114 today + 8 BF3 rows). user.reg: BF4 form 0, BF3 form 0, `E:\\EA Games\\` occurrences = 6 (2 today + 4). Number of lines in each file is unchanged; `userdef.reg` is not touched.

### b.2 S2 mapping: BF4 / Crysis 3 / F1 24 in system.reg (113 value rows, each: new = old with R-BF4 applied)

Columns: file:line | game | key (section header, without timestamp) | value name | old literal value as stored | new literal value as stored.

| file:line | game | key | value name | old | new |
|---|---|---|---|---|---|
| system.reg:12811 | F1 24 | `[Software\\Classes\\Installer\\Products\\005971D7C0AC65446B421C85671BF593\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` |
| system.reg:12822 | F1 24 | `[Software\\Classes\\Installer\\Products\\005971D7C0AC65446B421C85671BF593\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` |
| system.reg:12823 | F1 24 | `[Software\\Classes\\Installer\\Products\\005971D7C0AC65446B421C85671BF593\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` |
| system.reg:12866 | F1 24 | `[Software\\Classes\\Installer\\Products\\09CA60B386ED9A4459BEA0C3A11F15F4\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` |
| system.reg:12877 | F1 24 | `[Software\\Classes\\Installer\\Products\\09CA60B386ED9A4459BEA0C3A11F15F4\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` |
| system.reg:12878 | F1 24 | `[Software\\Classes\\Installer\\Products\\09CA60B386ED9A4459BEA0C3A11F15F4\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` |
| system.reg:12894 | F1 24 | `[Software\\Classes\\Installer\\Products\\12BE5B6FFBA0C7849B9A9DBD52C94430\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` |
| system.reg:12905 | F1 24 | `[Software\\Classes\\Installer\\Products\\12BE5B6FFBA0C7849B9A9DBD52C94430\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` |
| system.reg:12906 | F1 24 | `[Software\\Classes\\Installer\\Products\\12BE5B6FFBA0C7849B9A9DBD52C94430\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` |
| system.reg:12923 | F1 24 | `[Software\\Classes\\Installer\\Products\\1326810AB8A0A554A8526BA4BACC116A\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` |
| system.reg:12934 | F1 24 | `[Software\\Classes\\Installer\\Products\\1326810AB8A0A554A8526BA4BACC116A\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` |
| system.reg:12935 | F1 24 | `[Software\\Classes\\Installer\\Products\\1326810AB8A0A554A8526BA4BACC116A\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` |
| system.reg:13048 | F1 24 | `[Software\\Classes\\Installer\\Products\\3A0CEC8401EA3EE4CA26673D5D78295E\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` |
| system.reg:13059 | F1 24 | `[Software\\Classes\\Installer\\Products\\3A0CEC8401EA3EE4CA26673D5D78295E\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` |
| system.reg:13060 | F1 24 | `[Software\\Classes\\Installer\\Products\\3A0CEC8401EA3EE4CA26673D5D78295E\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` |
| system.reg:13158 | F1 24 | `[Software\\Classes\\Installer\\Products\\451B3F8EEC300214B8D9E938DEF5A37D\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` |
| system.reg:13169 | F1 24 | `[Software\\Classes\\Installer\\Products\\451B3F8EEC300214B8D9E938DEF5A37D\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` |
| system.reg:13170 | F1 24 | `[Software\\Classes\\Installer\\Products\\451B3F8EEC300214B8D9E938DEF5A37D\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` |
| system.reg:13239 | F1 24 | `[Software\\Classes\\Installer\\Products\\557FA94F3C5A25241A0975272B66C9B3\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` |
| system.reg:13250 | F1 24 | `[Software\\Classes\\Installer\\Products\\557FA94F3C5A25241A0975272B66C9B3\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` |
| system.reg:13251 | F1 24 | `[Software\\Classes\\Installer\\Products\\557FA94F3C5A25241A0975272B66C9B3\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` |
| system.reg:13322 | F1 24 | `[Software\\Classes\\Installer\\Products\\780334B3E26E5FB4799FA46F1E2C04C9\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` |
| system.reg:13333 | F1 24 | `[Software\\Classes\\Installer\\Products\\780334B3E26E5FB4799FA46F1E2C04C9\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` |
| system.reg:13334 | F1 24 | `[Software\\Classes\\Installer\\Products\\780334B3E26E5FB4799FA46F1E2C04C9\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` |
| system.reg:13377 | F1 24 | `[Software\\Classes\\Installer\\Products\\8739BFEB88E56624E81B9C8296448958\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` |
| system.reg:13388 | F1 24 | `[Software\\Classes\\Installer\\Products\\8739BFEB88E56624E81B9C8296448958\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` |
| system.reg:13389 | F1 24 | `[Software\\Classes\\Installer\\Products\\8739BFEB88E56624E81B9C8296448958\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` |
| system.reg:13406 | F1 24 | `[Software\\Classes\\Installer\\Products\\9525D899DEB3017489FF6D33785B24E9\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` |
| system.reg:13417 | F1 24 | `[Software\\Classes\\Installer\\Products\\9525D899DEB3017489FF6D33785B24E9\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` |
| system.reg:13418 | F1 24 | `[Software\\Classes\\Installer\\Products\\9525D899DEB3017489FF6D33785B24E9\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` |
| system.reg:13435 | F1 24 | `[Software\\Classes\\Installer\\Products\\A009D969184377A48B882D14064D7D72\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` |
| system.reg:13446 | F1 24 | `[Software\\Classes\\Installer\\Products\\A009D969184377A48B882D14064D7D72\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` |
| system.reg:13447 | F1 24 | `[Software\\Classes\\Installer\\Products\\A009D969184377A48B882D14064D7D72\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` |
| system.reg:13463 | F1 24 | `[Software\\Classes\\Installer\\Products\\A57A2DAB8071AB744A890298D0C2877A\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` |
| system.reg:13474 | F1 24 | `[Software\\Classes\\Installer\\Products\\A57A2DAB8071AB744A890298D0C2877A\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` |
| system.reg:13475 | F1 24 | `[Software\\Classes\\Installer\\Products\\A57A2DAB8071AB744A890298D0C2877A\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` |
| system.reg:13492 | F1 24 | `[Software\\Classes\\Installer\\Products\\AA471CC4CB52FF641B2E312BA4BF1624\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` |
| system.reg:13503 | F1 24 | `[Software\\Classes\\Installer\\Products\\AA471CC4CB52FF641B2E312BA4BF1624\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` |
| system.reg:13504 | F1 24 | `[Software\\Classes\\Installer\\Products\\AA471CC4CB52FF641B2E312BA4BF1624\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` |
| system.reg:13548 | F1 24 | `[Software\\Classes\\Installer\\Products\\AD5055C91C9FBC64F9F8CA838FAE15A8\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` |
| system.reg:13559 | F1 24 | `[Software\\Classes\\Installer\\Products\\AD5055C91C9FBC64F9F8CA838FAE15A8\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` |
| system.reg:13560 | F1 24 | `[Software\\Classes\\Installer\\Products\\AD5055C91C9FBC64F9F8CA838FAE15A8\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` |
| system.reg:13577 | F1 24 | `[Software\\Classes\\Installer\\Products\\BB44AAA8E78410D4FA6784A4BC09BDEF\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` |
| system.reg:13588 | F1 24 | `[Software\\Classes\\Installer\\Products\\BB44AAA8E78410D4FA6784A4BC09BDEF\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` |
| system.reg:13589 | F1 24 | `[Software\\Classes\\Installer\\Products\\BB44AAA8E78410D4FA6784A4BC09BDEF\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` |
| system.reg:13714 | F1 24 | `[Software\\Classes\\Installer\\Products\\D3968ADE28E91DF4898CD04C9F41E1F0\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` |
| system.reg:13725 | F1 24 | `[Software\\Classes\\Installer\\Products\\D3968ADE28E91DF4898CD04C9F41E1F0\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` |
| system.reg:13726 | F1 24 | `[Software\\Classes\\Installer\\Products\\D3968ADE28E91DF4898CD04C9F41E1F0\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` |
| system.reg:13743 | F1 24 | `[Software\\Classes\\Installer\\Products\\DAC9CF70CECF6814BB38FEC7CC3927AB\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` |
| system.reg:13754 | F1 24 | `[Software\\Classes\\Installer\\Products\\DAC9CF70CECF6814BB38FEC7CC3927AB\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` |
| system.reg:13755 | F1 24 | `[Software\\Classes\\Installer\\Products\\DAC9CF70CECF6814BB38FEC7CC3927AB\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` |
| system.reg:13802 | F1 24 | `[Software\\Classes\\Installer\\Products\\F76AA8988B99F7C469111BF189FEE687\\SourceList]` | `"LastUsedSource"` | `"n;2;E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` | `"n;2;E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` |
| system.reg:13813 | F1 24 | `[Software\\Classes\\Installer\\Products\\F76AA8988B99F7C469111BF189FEE687\\SourceList\\Net]` | `"1"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` |
| system.reg:13814 | F1 24 | `[Software\\Classes\\Installer\\Products\\F76AA8988B99F7C469111BF189FEE687\\SourceList\\Net]` | `"2"` | `str(2):"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` | `str(2):"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` |
| system.reg:69326 | F1 24 | `[Software\\Codemasters\\F1_24]` | `"Install Dir"` | `"E:\\EA Games\\BF4\\F1 24\\"` | `"E:\\EA Games\\F1 24\\"` |
| system.reg:69337 | Battlefield 4 | `[Software\\EA Games\\Battlefield 4]` | `"GDFBinary"` | `"E:\\EA Games\\BF4\\Battlefield 4\\__Installer\\GDFBinary_en_US_64.dll"` | `"E:\\EA Games\\Battlefield 4\\__Installer\\GDFBinary_en_US_64.dll"` |
| system.reg:69338 | Battlefield 4 | `[Software\\EA Games\\Battlefield 4]` | `"Install Dir"` | `"E:\\EA Games\\BF4\\Battlefield 4\\"` | `"E:\\EA Games\\Battlefield 4\\"` |
| system.reg:81731 | Battlefield 4 | `[Software\\Microsoft\\Windows\\CurrentVersion\\GameUX\\Games\\{2F7347F3-A11D-4327-BCBB-ECEBF68A21D7}]` | `"ConfigApplicationPath"` | `"E:\\EA Games\\BF4\\Battlefield 4\\"` | `"E:\\EA Games\\Battlefield 4\\"` |
| system.reg:81732 | Battlefield 4 | `[Software\\Microsoft\\Windows\\CurrentVersion\\GameUX\\Games\\{2F7347F3-A11D-4327-BCBB-ECEBF68A21D7}]` | `"ConfigGDFBinaryPath"` | `"E:\\EA Games\\BF4\\Battlefield 4\\__Installer\\GDFBinary_en_US_64.dll"` | `"E:\\EA Games\\Battlefield 4\\__Installer\\GDFBinary_en_US_64.dll"` |
| system.reg:81739 | Battlefield 4 | `[Software\\Microsoft\\Windows\\CurrentVersion\\GameUX\\Games\\{36F2010B-A7AD-4B87-9E16-AC655FCE5A42}]` | `"ConfigApplicationPath"` | `"E:\\EA Games\\BF4\\Battlefield 4\\"` | `"E:\\EA Games\\Battlefield 4\\"` |
| system.reg:81740 | Battlefield 4 | `[Software\\Microsoft\\Windows\\CurrentVersion\\GameUX\\Games\\{36F2010B-A7AD-4B87-9E16-AC655FCE5A42}]` | `"ConfigGDFBinaryPath"` | `"E:\\EA Games\\BF4\\Battlefield 4\\__Installer\\GDFBinary_en_US.dll"` | `"E:\\EA Games\\Battlefield 4\\__Installer\\GDFBinary_en_US.dll"` |
| system.reg:90592 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\005971D7C0AC65446B421C85671BF593\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` |
| system.reg:90667 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\09CA60B386ED9A4459BEA0C3A11F15F4\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` |
| system.reg:90706 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\12BE5B6FFBA0C7849B9A9DBD52C94430\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` |
| system.reg:90744 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\1326810AB8A0A554A8526BA4BACC116A\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` |
| system.reg:90931 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\3A0CEC8401EA3EE4CA26673D5D78295E\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` |
| system.reg:91075 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\451B3F8EEC300214B8D9E938DEF5A37D\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` |
| system.reg:91179 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\557FA94F3C5A25241A0975272B66C9B3\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` |
| system.reg:91284 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\780334B3E26E5FB4799FA46F1E2C04C9\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` |
| system.reg:91358 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\8739BFEB88E56624E81B9C8296448958\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` |
| system.reg:91396 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\9525D899DEB3017489FF6D33785B24E9\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` |
| system.reg:91436 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\A009D969184377A48B882D14064D7D72\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` |
| system.reg:91477 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\A57A2DAB8071AB744A890298D0C2877A\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` |
| system.reg:91515 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\AA471CC4CB52FF641B2E312BA4BF1624\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` |
| system.reg:91590 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\AD5055C91C9FBC64F9F8CA838FAE15A8\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` |
| system.reg:91630 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\BB44AAA8E78410D4FA6784A4BC09BDEF\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` |
| system.reg:91811 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\D3968ADE28E91DF4898CD04C9F41E1F0\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` |
| system.reg:91851 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\DAC9CF70CECF6814BB38FEC7CC3927AB\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` |
| system.reg:91930 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\F76AA8988B99F7C469111BF189FEE687\\InstallProperties]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` |
| system.reg:94712 | F1 24 | `[Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{3B433087-E62E-4BF5-97F9-4AF6E1C2409C}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq1_speech\\"` |
| system.reg:102887 | F1 24 | `[Software\\Wow6432Node\\Codemasters\\F1_24]` | `"Install Dir"` | `"E:\\EA Games\\BF4\\F1 24\\"` | `"E:\\EA Games\\F1 24\\"` |
| system.reg:102898 | Crysis 3 | `[Software\\Wow6432Node\\Crytek\\Crysis 3]` | `"GDFBinary"` | `"E:\\EA Games\\BF4\\Crysis 3\\GDFBinary_en_US.dll"` | `"E:\\EA Games\\Crysis 3\\GDFBinary_en_US.dll"` |
| system.reg:102899 | Crysis 3 | `[Software\\Wow6432Node\\Crytek\\Crysis 3]` | `"Install Dir"` | `"E:\\EA Games\\BF4\\Crysis 3\\"` | `"E:\\EA Games\\Crysis 3\\"` |
| system.reg:102914 | Battlefield 4 | `[Software\\Wow6432Node\\EA Games\\Battlefield 4]` | `"GDFBinary"` | `"E:\\EA Games\\BF4\\Battlefield 4\\__Installer\\GDFBinary_en_US.dll"` | `"E:\\EA Games\\Battlefield 4\\__Installer\\GDFBinary_en_US.dll"` |
| system.reg:102915 | Battlefield 4 | `[Software\\Wow6432Node\\EA Games\\Battlefield 4]` | `"GDFBinary64"` | `"E:\\EA Games\\BF4\\Battlefield 4\\__Installer\\GDFBinary_en_US_64.dll"` | `"E:\\EA Games\\Battlefield 4\\__Installer\\GDFBinary_en_US_64.dll"` |
| system.reg:102916 | Battlefield 4 | `[Software\\Wow6432Node\\EA Games\\Battlefield 4]` | `"Install Dir"` | `"E:\\EA Games\\BF4\\Battlefield 4\\"` | `"E:\\EA Games\\Battlefield 4\\"` |
| system.reg:111004 | BF4 (PunkBuster Services uninstall key) | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\PunkBusterSvc]` | `"UninstallString"` | `str(2):"E:\\EA Games\\BF4\\Battlefield 4\\pbsvc.exe -u"` | `str(2):"E:\\EA Games\\Battlefield 4\\pbsvc.exe -u"` |
| system.reg:111090 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{07FC9CAD-FCEC-4186-BB83-EF7CCC9372BA}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq12_speech_en_NZ\\"` |
| system.reg:111135 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{12151659-5588-4775-BEB0-34E053E23212}]` | `"DisplayIcon"` | `"\"E:\\EA Games\\BF4\\F1 24\\F1_24.exe\""` | `"\"E:\\EA Games\\F1 24\\F1_24.exe\""` |
| system.reg:111139 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{12151659-5588-4775-BEB0-34E053E23212}]` | `"HelpLink"` | `"E:\\EA Games\\BF4\\F1 24\\Support\\EA Help\\Technical Support.en_GB.rtf"` | `"E:\\EA Games\\F1 24\\Support\\EA Help\\Technical Support.en_GB.rtf"` |
| system.reg:111140 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{12151659-5588-4775-BEB0-34E053E23212}]` | `"InstallLocation"` | `"E:\\EA Games\\BF4\\F1 24\\"` | `"E:\\EA Games\\F1 24\\"` |
| system.reg:111208 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{3B06AC90-DE68-44A9-95EB-0A3C1AF1514F}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq2_speech_en_IN\\"` |
| system.reg:111224 | Crysis 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{4198AE83-A3C6-4C41-85C8-EC63E990696E}]` | `"DisplayIcon"` | `"\"E:\\EA Games\\BF4\\Crysis 3\\Bin32\\Crysis3.exe\""` | `"\"E:\\EA Games\\Crysis 3\\Bin32\\Crysis3.exe\""` |
| system.reg:111228 | Crysis 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{4198AE83-A3C6-4C41-85C8-EC63E990696E}]` | `"HelpLink"` | `"E:\\EA Games\\BF4\\Crysis 3\\Support\\EA Help\\Technical Support.en_US.rtf"` | `"E:\\EA Games\\Crysis 3\\Support\\EA Help\\Technical Support.en_US.rtf"` |
| system.reg:111229 | Crysis 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{4198AE83-A3C6-4C41-85C8-EC63E990696E}]` | `"InstallLocation"` | `"E:\\EA Games\\BF4\\Crysis 3\\"` | `"E:\\EA Games\\Crysis 3\\"` |
| system.reg:111246 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{48CEC0A3-AE10-4EE3-AC62-76D3D58792E5}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq8_speech_en_AU\\"` |
| system.reg:111274 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{4CC174AA-25BC-46FF-B1E2-13B24AFB6142}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq17_speech_fr_FR\\"` |
| system.reg:111337 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{7D179500-CA0C-4456-B624-C15876B15F39}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq16_speech_fr_CA\\"` |
| system.reg:111393 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{898AA67F-99B8-4C7F-9611-B11F98EF6E78}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq7_speech_de_DE\\"` |
| system.reg:111421 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{8AAA44BB-487E-4D01-AF76-484ACB90DBFE}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq13_speech_en_US\\"` |
| system.reg:111498 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{969D900A-3481-4A77-B888-D24160D4D727}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq18_speech_it_IT\\"` |
| system.reg:111526 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{998D5259-3BED-4710-98FF-D63387B5429E}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq11_speech_en_IE\\"` |
| system.reg:111582 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{9C5505DA-F9C1-46CB-9F8F-AC38F8EA518A}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq9_speech_en_CA\\"` |
| system.reg:111633 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{A0186231-0A8B-455A-8A25-B64AABCC11A6}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq10_speech_en_GB\\"` |
| system.reg:111674 | Battlefield 4 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{ABADE36E-EC37-413B-8179-B432AD3FACE7}]` | `"DisplayIcon"` | `"\"E:\\EA Games\\BF4\\Battlefield 4\\BFLauncher_x86.exe\""` | `"\"E:\\EA Games\\Battlefield 4\\BFLauncher_x86.exe\""` |
| system.reg:111678 | Battlefield 4 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{ABADE36E-EC37-413B-8179-B432AD3FACE7}]` | `"HelpLink"` | `"E:\\EA Games\\BF4\\Battlefield 4\\Support\\EA Help\\Technical Support.en_US.rtf"` | `"E:\\EA Games\\Battlefield 4\\Support\\EA Help\\Technical Support.en_US.rtf"` |
| system.reg:111679 | Battlefield 4 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{ABADE36E-EC37-413B-8179-B432AD3FACE7}]` | `"InstallLocation"` | `"E:\\EA Games\\BF4\\Battlefield 4\\"` | `"E:\\EA Games\\Battlefield 4\\"` |
| system.reg:111724 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{BAD2A75A-1708-47BA-A498-20890D2C78A7}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq6_speech_zh_CN\\"` |
| system.reg:111778 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{BEFB9378-5E88-4266-8EB1-C92869449885}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq3_speech_pl_PL\\"` |
| system.reg:111904 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{E8F3B154-03CE-4120-8B9D-9E83ED5F3AD7}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq15_speech_es_MX\\"` |
| system.reg:111932 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{EDA8693D-9E82-4FD1-98C8-0DC4F9141E0F}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq19_speech_ja_JP\\"` |
| system.reg:112064 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{F49AF755-A5C3-4252-A190-5772B2669C3B}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq14_speech_es_ES\\"` |
| system.reg:112114 | F1 24 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{F6B5EB21-0ABF-487C-B9A9-D9DB259C4403}]` | `"InstallSource"` | `"E:\\EA Games\\BF4\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` | `"E:\\EA Games\\F1 24\\__Installer\\customcomponent\\CustomPrereq4_speech_pt_BR\\"` |

### b.3 S2 key-NAME hits (user.reg; need a key-header rewrite, not a value edit)

These six are keys whose NAME contains a path: Qt 4.x plugin caches written by the games' `Core\*.dll` (nested keys `...\\com.trolltech.Qt.QImageIOHandlerFactoryInterface:\\E:\\EA Games\\BF4\\Battlefield 4\\Core\\imageformats` etc.). They only cache plugin file timestamps (`"qgif4.dll"=str(7):"2026-10-10T20:10:07\0gif\0"`); they are safe to rewrite by a header substring replace (rows below, S2 and S4), safe to delete, or safe to ignore (the game recreates them). No other key names in any hive contain an old path (checked: every hit in system.reg is a value, never a header or a value name; no AppCompat/Layers/MUICache entries keyed by an exe path exist; the only drive-letter value names are the three `msdia*.dll` SharedDLLs entries).

| file:line | game | old key header | new key header |
|---|---|---|---|
| user.reg:1046 | Battlefield 4 | `[Software\\Trolltech\\OrganizationDefaults\\Qt Factory Cache 4.8\\com.trolltech.Qt.QImageIOHandlerFactoryInterface:\\E:\\EA Games\\BF4\\Battlefield 4\\Core\\imageformats]` | `[Software\\Trolltech\\OrganizationDefaults\\Qt Factory Cache 4.8\\com.trolltech.Qt.QImageIOHandlerFactoryInterface:\\E:\\EA Games\\Battlefield 4\\Core\\imageformats]` |
| user.reg:1065 | Battlefield 4 | `[Software\\Trolltech\\OrganizationDefaults\\Qt Plugin Cache 4.8.false\\E:\\EA Games\\BF4\\Battlefield 4\\Core\\imageformats]` | `[Software\\Trolltech\\OrganizationDefaults\\Qt Plugin Cache 4.8.false\\E:\\EA Games\\Battlefield 4\\Core\\imageformats]` |

### b.4 S2 mapping: files outside the registry

| File | Form | Old (exact) | New | Editable? |
|---|---|---|---|---|
| `P/drive_c/users/crossover/AppData/Local/Electronic Arts/EA Desktop/user_5453960179173819204.ini` (561 B, mtime 2026-10-11 18:16:48) | plain ASCII, CRLF, no BOM; last line | `user.downloadinplacedir=E:\EA Games\BF4\` + CRLF (the line starts at byte offset 0x20e, it is the last line) | `user.downloadinplacedir=E:\EA Games\` + CRLF (file becomes 553 B) | yes, plain text. EA rewrites this file when it exits, so edit only with EA stopped. Other keys in the file hold no path (`user.lastgamelaunched.offerid=OFB-EAST:49562` = Crysis 3, `user.userid`, window geometry). `cookie.ini` and `telemetry.ini` have no path keys. |
| `P/drive_c/users/Public/Desktop/Battlefield 4.lnk` (570 B) | binary shell link: ASCII LinkInfo path `E:\EA Games\BF4\Battlefield 4\BFLauncher_x86.exe`, UTF-16 working dir `E:\EA Games\BF4\Battlefield 4`, plus shell-item IDList components `EA Games`, `BF4`, `Battlefield 4`, `BFLauncher_x86.exe` | `E:\EA Games\Battlefield 4\...` | NOT safely text-editable (length-prefixed structure, IDList). Recreate the shortcut or accept it dangling. |
| `.../Public/Desktop/Crysis 3.lnk` (584 B) | same shape; target `E:\EA Games\BF4\Crysis 3\Bin32\Crysis3.exe`, workdir `E:\EA Games\BF4\Crysis 3\Bin32` | `E:\EA Games\Crysis 3\Bin32\...` | same: recreate |
| `.../Public/Desktop/F1® 24.lnk` (485 B) | target `E:\EA Games\BF4\F1 24\F1_24.exe` (ASCII LinkInfo only) | `E:\EA Games\F1 24\F1_24.exe` | same: recreate |
| `P/drive_c/ProgramData/Package Cache/{a1909659-0a08-4554-8af1-2175904903a1}/state.rsm` (752 B) and `{95716cce-fc71-413f-8ad5-56c2892d4b3a}/state.rsm` (736 B) | WiX Burn state, UTF-16LE, length-prefixed variable `WixBundleOriginalSource` = `E:\EA Games\BF4\Battlefield 4\__Installer\vc\vc2012Update3\redist\vcredist_x64.exe` / `..._x86.exe` | `E:\EA Games\Battlefield 4\...` | Not safely editable (a DWORD char count precedes the string). Only matters for repair/uninstall of the VC++ 2012 redist bundle. Leave alone. |
| `{050d4fc8-5d48-4b8f-8972-47c82c46020f}/state.rsm`, `{f65db027-aff3-4070-886a-0d87064aabb1}/state.rsm` | same, but the source is `E:\EA Games\BF4\Battlefield 1\__Installer\vc\vc2013\redist\...` (Battlefield 1 was removed on 2026-10-11, see `cleanup-bf1-f1-20261011.log`) | stale | ignore |
| Inside the games: `__Installer/installerdata.xml` (BF4, Crysis 3, F1 24, BF3, NFS) | holds registry templates only, e.g. `<filePath>[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Battlefield 4\Install Dir]BFLauncher.exe</filePath>`; no absolute paths | none | no edit; but these templates make the registry `Install Dir` values the single source of truth for each game's location |
| Inside the games: `__Installer/InstallLog.txt` (UTF-16LE, historical install logs: BF4 23 hits, Crysis 3 17, F1 24 105, BF3 52 `Program Files\EA Games\Battlefield 3` hits, NFS 9, plus `__Installer/DLC/Xpack*/__Installer/InstallLog.txt` 9 each) | log text | n/a | do not edit; they are logs (EA appends to them) |
| `BF3/Support/Read Me.lnk` (761 B) | binary shell link with `C:\Program Files\EA Games\Battlefield 3\...` | | not editable; irrelevant to launching (it is the target of the `Readme` registry value) |
| `Documents/Battlefield 3`, `Documents/Battlefield 4`, `Documents/Need For Speed`, `Saved Games/Crysis3` (crossover profile) | settings, saves, dumps | none | **no file stores an absolute install path** (searched for every path form, ASCII and UTF-16; the NFS `*.dmp` crash dumps contain the text "Need for Speed" only) |
| Game roots: `.xml/.ini/.cfg/.json/.txt/.dat/.htm/.rtf/.js/.mft` files | all five games | none | no absolute path other than the InstallLog.txt files above; `BF3/Core/EACore_App.ini` (UTF-16LE with BOM) and `BF3/version.json` contain no path. (`ext2` hits in EULA .rtf/.js files are the text "Text2"-style false positives.) |

### b.5 S4 mapping: Battlefield 3 (C:\Program Files\EA Games\Battlefield 3 -> E:\EA Games\Battlefield 3)

Registry value rows (system.reg; new = old with R-BF3 applied):

| file:line | game | key | value name | old | new |
|---|---|---|---|---|---|
| system.reg:81747 | Battlefield 3 | `[Software\\Microsoft\\Windows\\CurrentVersion\\GameUX\\Games\\{A15F8AC8-5D0C-49B1-B920-FA40AD445D3A}]` | `"ConfigApplicationPath"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\"` | `"E:\\EA Games\\Battlefield 3\\"` |
| system.reg:81748 | Battlefield 3 | `[Software\\Microsoft\\Windows\\CurrentVersion\\GameUX\\Games\\{A15F8AC8-5D0C-49B1-B920-FA40AD445D3A}]` | `"ConfigGDFBinaryPath"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\GDFBinary_en_US.dll"` | `"E:\\EA Games\\Battlefield 3\\GDFBinary_en_US.dll"` |
| system.reg:102906 | Battlefield 3 | `[Software\\Wow6432Node\\EA Games\\Battlefield 3]` | `"GDFBinary"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\GDFBinary_en_US.dll"` | `"E:\\EA Games\\Battlefield 3\\GDFBinary_en_US.dll"` |
| system.reg:102907 | Battlefield 3 | `[Software\\Wow6432Node\\EA Games\\Battlefield 3]` | `"Install Dir"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\"` | `"E:\\EA Games\\Battlefield 3\\"` |
| system.reg:111315 | Battlefield 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{76285C16-411A-488A-BCE3-C83CB933D8CF}]` | `"DisplayIcon"` | `"\"C:\\Program Files\\EA Games\\Battlefield 3\\bf3.exe\""` | `"\"E:\\EA Games\\Battlefield 3\\bf3.exe\""` |
| system.reg:111318 | Battlefield 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{76285C16-411A-488A-BCE3-C83CB933D8CF}]` | `"HelpLink"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\Support\\EA Help\\Electronic_Arts_Technical_Support.htm"` | `"E:\\EA Games\\Battlefield 3\\Support\\EA Help\\Electronic_Arts_Technical_Support.htm"` |
| system.reg:111319 | Battlefield 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{76285C16-411A-488A-BCE3-C83CB933D8CF}]` | `"InstallLocation"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\"` | `"E:\\EA Games\\Battlefield 3\\"` |
| system.reg:111321 | Battlefield 3 | `[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{76285C16-411A-488A-BCE3-C83CB933D8CF}]` | `"Readme"` | `"C:\\Program Files\\EA Games\\Battlefield 3\\Support\\Read Me.lnk"` | `"E:\\EA Games\\Battlefield 3\\Support\\Read Me.lnk"` |

Registry key-name rows (user.reg; Qt plugin caches, same remarks as b.3):

| file:line | game | old key header | new key header |
|---|---|---|---|
| user.reg:1034 | Battlefield 3 | `[Software\\Trolltech\\OrganizationDefaults\\Qt Factory Cache 4.7\\com.trolltech.Qt.QImageIOHandlerFactoryInterface:\\C:\\Program Files\\EA Games\\Battlefield 3\\Core\\imageformats]` | `[Software\\Trolltech\\OrganizationDefaults\\Qt Factory Cache 4.7\\com.trolltech.Qt.QImageIOHandlerFactoryInterface:\\E:\\EA Games\\Battlefield 3\\Core\\imageformats]` |
| user.reg:1040 | Battlefield 3 | `[Software\\Trolltech\\OrganizationDefaults\\Qt Factory Cache 4.7\\com.trolltech.Qt.QTextCodecFactoryInterface:\\C:\\Program Files\\EA Games\\Battlefield 3\\Core\\codecs]` | `[Software\\Trolltech\\OrganizationDefaults\\Qt Factory Cache 4.7\\com.trolltech.Qt.QTextCodecFactoryInterface:\\E:\\EA Games\\Battlefield 3\\Core\\codecs]` |
| user.reg:1052 | Battlefield 3 | `[Software\\Trolltech\\OrganizationDefaults\\Qt Plugin Cache 4.7.false\\C:\\Program Files\\EA Games\\Battlefield 3\\Core\\codecs]` | `[Software\\Trolltech\\OrganizationDefaults\\Qt Plugin Cache 4.7.false\\E:\\EA Games\\Battlefield 3\\Core\\codecs]` |
| user.reg:1059 | Battlefield 3 | `[Software\\Trolltech\\OrganizationDefaults\\Qt Plugin Cache 4.7.false\\C:\\Program Files\\EA Games\\Battlefield 3\\Core\\imageformats]` | `[Software\\Trolltech\\OrganizationDefaults\\Qt Plugin Cache 4.7.false\\E:\\EA Games\\Battlefield 3\\Core\\imageformats]` |

Other BF3 records (no edit needed or possible): `Software\\Wow6432Node\\Electronic Arts\\Battlefield 3` (`Uninstall Program` = `C:\\Program Files (x86)\\Common Files\\EAInstaller\\Battlefield 3\\Cleanup.exe`, stays); `HKLM\SOFTWARE\Wine\AppDefaults\bf3.exe\DllOverrides` (keyed by exe name, not path; system.reg:102680, user.reg:1071). BF3 has no `Origin Games\<id>` key (only BF4, Crysis 3, F1 24 have one, and those hold just `DisplayName`/`Locale`), no `Core\` activation registry record, and no `InstallData` folder in `ProgramData/EA Desktop`. Its `70619.dlf` licence is at `ProgramData/Electronic Arts/EA Services/License/70619.dlf` (577 B, 2026-10-11 12:53) plus `70619.dlf.stale-machine-hash-20261011`; `.dlf` files must not be opened or altered and nothing path-related is expected in them.

### b.6 S3 mapping: NFS mirror

No registry or file record in the shared prefix names the mirror path (`C:\Program Files\EA Games\Need for Speed`): searched system/user/userdef.reg, all of `P/drive_c`, EA Desktop logs (0 hits for `Program Files\EA Games\Need for Speed`). Removing the mirror therefore needs no edit in `P`. Records that will dangle after removal live only in the *old wrapper prefix* `G/Relocated/NFS2015Mac/Data/Prefix` (its own `system.reg:97013` `"Install Dir"="C:\\Program Files\\EA Games\\Need for Speed\\"` and two Qt cache key names in its user.reg:994/1000); S3 must not edit them (that prefix is only used by the old NFS wrapper, which will stop working once its game folder is removed). `~/Library/Application Support/NFS2015Mac/Data/Prefix` is a symlink to `G/Relocated/NFS2015Mac/Data/Prefix`.

---

## (c) Records that are NOT editable (opaque) and what to expect

| Item | Nature | Contains old path? | Expectation |
|---|---|---|---|
| `P/drive_c/ProgramData/EA Desktop/530c11479fe252fc5aabc24935b9776d4900eb3ba58fdc271e0d6229413ad40e/IS` (16800 B, 18:01), `IQ` (15568 B), `CATS2` (61312 B), `CONF-production` (30672 B, mtime 18:48:13, EA writes it constantly) | encrypted: 32 ASCII-hex IV/header chars then ciphertext, entropy 7.99 bits/byte | cannot be searched; no plaintext path visible | **IS is EA's install store** (the log shows it deserialised as `deserializeInstallStoreV1` with `launcher.exePath=[[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Battlefield 4\Install Dir]BFLauncher.exe]` templates). Install locations are resolved through those registry `Install Dir` values, so correct registry values + moved files should make EA re-run `reconcileContentInstallInfo` ("Located files for software [...]. Setting state to Installed") and update IS itself. Leave the four files untouched. Do not try to edit them. |
| `.../EA Desktop/3ec92d46792ee67bb470076f38a3bdc401f7a99877561f0b7b3735e62ab8ef09/NS` (20624 B) | encrypted, same shape | unknown | leave |
| `.../EA Desktop/PLR/production/9fb714fb...` | empty directory | | n/a |
| `.../EA Desktop/InstallData/*/*/map.eacrc` (8 files) | binary `E4X$01` records (u16 length + relative path + 4-byte hash), **relative paths only** (`__Installer/installerdata.xml`, `Update/Xpack1/package.mft`, `Data/Win32/...`). Searched ASCII and UTF-16 for `:\`, `Games`, `Program Files`, `ExT2`, `Volumes`: none (one `y:/` hit in the F1 24 file is random bytes) | no | no edit needed; they stay valid after the moves |
| `P/drive_c/ProgramData/Electronic Arts/EA Services/License/*.dlf` (`1007968.dlf` = BF4 base, `16425782.dlf` = F1 24, `71503.dlf` = Crysis 3, `70619.dlf` = BF3, `1024486.dlf` = NFS; sizes/mtimes: 433 B 15:57, 577 B 22:24 Oct 10, 577 B 12:53, 1889 B 17:43, 577 B 20:11 Oct 10) and `70619.dlf.stale-machine-hash-20261011` | EA-signed machine-bound licences | not opened | never open or edit. The licence binds to a machine fingerprint including the storage/drive count (NFS plan D5): **do not add or remove entries in `P/dosdevices`**. |
| `ProgramData/Package Cache/{...}/state.rsm` (4 files) | Burn state | yes (see b.4) | leave; only affects VC++ redist repair |
| `Public/Desktop/*.lnk` (3 game shortcuts) | binary shell links | yes (see b.4) | recreate or accept |
| EA logs (`EADesktop*.log/.bak`, `EABackgroundService*.log`, `EAGEP*.log`, `IGO_*.log`, `Origin/Logs/*.html`, `AppData/.../EAapp_OnlineActivation_Log.html`, `Temp/dd_vcredist_*.log`, `Roaming/EAAntiCheat.Installer.Tool/*.log`) | history | many | never edit |

---

## (d) Baselines (taken at survey time; for later verification)

Method: python `os.walk(followlinks=False)` + `os.lstat`; "files" = regular files (`st_size` sum), symlinks counted via `S_ISLNK`, `nlink>1` among regular files. `.DS_Store` files are included in the counts.

| Folder | files | total bytes | dirs | symlinks inside | files with link count > 1 | `.DS_Store` among files |
|---|---|---|---|---|---|---|
| BF4 `G/EA Games/BF4/Battlefield 4` | 764 | 66,018,133,291 | 174 | 0 | 0 | 6 |
| Crysis 3 `G/EA Games/BF4/Crysis 3` | 519 | 11,371,404,328 | 89 | 0 | 0 | 4 |
| F1 24 `G/EA Games/BF4/F1 24` | 29,496 | 70,602,312,844 | 3,130 | 0 | 0 | 31 |
| BF3 `P/drive_c/Program Files/EA Games/Battlefield 3` | 1,872 | 21,382,885,726 | 146 | 0 | 0 | 0 |
| NFS `G/EA Games/Need for Speed` | 144 | 14,639,595,955 | 25 | 0 | 144 (all 2) | 0 |
| NFS mirror `G/Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed` | 144 | 14,639,595,955 | 25 | 0 | 144 (all 2) | 0 |

**NFS mirror check: CLEAN.** All 144 mirror files have link count 2; for every one the (device, inode) equals the same-relative-path file under `G/EA Games/Need for Speed` (144 matches, 0 mismatches); 0 mirror-only files, 0 NFS files missing from the mirror, 0 non-regular entries (no symlinks, sockets, devices); directory sets are identical (25 = 25, none mirror-only or source-only). So the mirror contains **no data that is not a hard link**: removing it frees no space and loses nothing (the data stays alive via `G/EA Games/Need for Speed`). The 25 mirror directories are empty of unique content once the 144 links are unlinked.

Free space `df -k /Volumes/ExT2`: 976557744 blocks total, 776849324 used, **199,708,420 KiB available** (80 %); it fluctuates (200,399,172 KiB ten minutes earlier) because other jobs write to the volume. All planned moves are same-volume renames (APFS `/dev/disk15s1`), so no extra space is needed.

Hive hashes at survey time (SHA-256): `system.reg` b7483129c066c0578c787264e22e64691e6f71b11f3ee090249c2c16ff0d5c9f (5,390,594 B), `user.reg` 2d2f3e6e4115de082dc2391738ff538f5f3bdd527593aa011fc7d5d547aeda88 (261,255 B), `userdef.reg` 6f3e0c1b519947eda5fb18536987b9010d66bef0bd56ab28c7cb0d04ff2357d6 (4,156 B). The ini above: 561 B, mtime 2026-10-11 18:16:48.

Process baseline: no wineserver for `P`. Running wine processes (pids 93725, 93737..93808, 98841, 99116) all have `WINEPREFIX=/Volumes/ExT2/GameHub/work/wine-gepperf-tools/prefix` (verified through `ps eww`), other job: leave alone. Note that a wine/EA process of `P` would carry `WINEPREFIX=/Volumes/ExT2/GameHub/Prefix` (and `start-ea.sh` shows as `/bin/bash /Volumes/ExT2/GameHub/bin/start-ea.sh`). Wine's socket dir for `P` is `/tmp/.wine-<uid>/server-<hex st_dev>-<hex st_ino>` (`stat -f '%d %i'` of `P`: dev 16777260, ino 1133755 on 2026-10-11; may have changed).

### Pre-move "good" EA log state (EA Desktop Logs in `P/drive_c/ProgramData/EA Desktop/Logs`)

Last EA session start before this survey: 2026-10-11T16:01:21Z (UTC, = 18:01 local). Logs present: `EADesktop.log`, `EADesktopVerbose.log/.bak`, `EABackgroundService.log`, `EABackgroundServiceVerbose.log/.bak`, `EALocalHostSvc*.log/.bak`, `EAGEP*.log`, `EALaunchHelper*.log`, `EALauncher*.log`, `IGO_*`, `cef.log`, `EADestager*.log`, `*.mdmp`, `temp*.tmp`.
`installedStatus` (EADesktop.log, 2026-10-11T16:01:21.88Z, format: `IS update: set installInfo for softwareId=[ID] baseSlug=[slug] installedStatus=[Installed]`):

| Game | softwareId | slug | other ids |
|---|---|---|---|
| Battlefield 4 base | `Origin.SFT.50.0000019` | battlefield-4 | content/offer 1007968, Product GUID `{ABADE36E-EC37-413B-8179-B432AD3FACE7}`, offerId `OFB-EAST:...` for launch |
| BF4 DLC Xpack1 China Rising (name mapping inferred from registry timestamps) | `Origin.SFT.50.0000105` | battlefield-4 | 1004841 |
| BF4 DLC Xpack0 Second Assault | `Origin.SFT.50.0000133` | battlefield-4 | 1011887 |
| BF4 DLC Xpack2 Naval Strike | `Origin.SFT.50.0000175` | battlefield-4 | 1004842 |
| BF4 DLC Xpack3 Dragon's Teeth | `Origin.SFT.50.0000193` | battlefield-4 | 1011893 |
| BF4 DLC Xpack4 Final Stand | `Origin.SFT.50.0000194` | battlefield-4 | 1011899 |
| Crysis 3 | `6b22703e-6861-4356-b13e-a77b76be7d7a` | crysis-3 | contentId 71503, offerId `OFB-EAST:49562`, GUID `{4198AE83-A3C6-4C41-85C8-EC63E990696E}` |
| F1 24 | `Origin.SFT.50.0001497` | f1-24 | content 16425782, GUID `{12151659-5588-4775-BEB0-34E053E23212}` |
| Battlefield 3 | `c9617fe2-f4dc-4a8f-b661-295f3924245f` | battlefield-3 | contentId 70619, offerId `DR:225064100`, GUID `{76285C16-411A-488A-BCE3-C83CB933D8CF}` |
| Need for Speed | `Origin.SFT.50.0000347` | need-for-speed | contentId 1024486, offerId `Origin.OFR.50.0000810`, GUID `{F8643E83-A868-4EE8-A0B9-389386830453}` |
| (Battlefield 1 `Origin.SFT.50.0000267`) | | | still logged Installed at 16:01Z; removed at 16:43Z by the cleanup, now NotInstalled and gone from the registry |

`watchPath` (EABackgroundServiceVerbose.log, 16:01:24Z; the "good" install-check lines):
`ContentInstallStateWatcher::watchPath path [E:\EA Games\BF4\Battlefield 4\bf4.exe] for software [Origin.SFT.50.0000019]`; `... [E:\EA Games\BF4\Battlefield 4\Update\Xpack{0..4}\Data\Win32\XP{n}\Levels\...\*.sb] for software [Origin.SFT.50.0000{133,105,175,193,194}]`; `... [E:\EA Games\BF4\Crysis 3\Bin32\crysis3.exe] for software [6b22703e-...]`; `... [E:\EA Games\BF4\F1 24\__Installer\installerdata.xml] for software [Origin.SFT.50.0001497]`; `... [C:\Program Files\EA Games\Battlefield 3\bf3.exe] for software [c9617fe2-...]`; `... [E:\EA Games\Need for Speed\NFS16.exe] for software [Origin.SFT.50.0000347]`. After the moves the expected lines are the same with `E:\EA Games\Battlefield 4\bf4.exe`, `E:\EA Games\Crysis 3\Bin32\crysis3.exe`, `E:\EA Games\F1 24\__Installer\installerdata.xml`, `E:\EA Games\Battlefield 3\bf3.exe`.
`exePath` (EADesktop.log): `Got exePath=[E:\EA Games\BF4\Crysis 3\Bin32\Crysis3.exe] cmdArgs=[] from defaultLauncher` (last 16:16:04Z), `[E:\EA Games\BF4\Battlefield 4\BFLauncher.exe]` (14:50Z), `[E:\EA Games\BF4\F1 24\EAAntiCheat.GameServiceLauncher.exe]` (13:57Z), `[C:\Program Files\EA Games\Battlefield 3\BF3WebHelper.exe]` (14:03Z), `[E:\EA Games\Need for Speed\NFS16.exe]` (15:43Z).
`Located files for software [...]. Setting state to Installed`: only one line survives in the live logs (EABackgroundService.log line 99, 2026-10-10T00:05:31Z, BF3 `c9617fe2-...`, also in `EABackgroundServiceVerbose.bak`); BF4/Crysis 3/F1 24 were installed by EA itself (no "Located files" line), NFS was imported with the registry key (see precedent). The EA background service resolves every game through `launcher.exePath=[[HKEY_LOCAL_MACHINE\SOFTWARE\Crytek\Crysis 3\Install Dir]Crysis3.exe]`-style templates read in `deserializeInstallStoreV1` (`EA Games\Battlefield 4`, `Crytek\Crysis 3`, `Codemasters\F1_24`, `EA Games\Need for Speed` seen).

---

## Appendix A: how EA is started and stopped here

`G/bin/` holds only `start-ea.sh`, `start-ea.sh.bak-1800` (previous version; the diff is the optional x87 toggle) and `wine-query.sh` (runs `wine cmd /c dir <path>` with the same env, 90 s timeout). There is **no stop script**.

`start-ea.sh` (bash, 1102 B, mtime 18:02), verbatim behaviour:
- `RT=${HUB_RUNTIME:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv}`; `R="/Users/gc/Library/Application Support/BF3Mac"`; log `G/Hub/Logs/ea-<YYYYmmdd-HHMMSS>.log` (also reachable as `G/Logs`, a symlink to `Hub/Logs`; latest logs `ea-20261011-180114.log` 38 KB etc.).
- `WINE_COMPATDB` is a v3 rule list: `EACefSubProcess.exe` and `EAGEP.exe` -> `dxgi=wined3d`; default `exe=*` -> `d3d9=mtld3d;dxgi=dxmt`.
- x87 sidecar: `ROSETTA_X87_PATH=${HUB_X87_PATH:-/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar}` unless `HUB_X87=off` (then `ROSETTA_X87_PATH=` empty).
- Command: `cd "$R" && nohup env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" WINEPREFIX="/Volumes/ExT2/GameHub/Prefix" WINEDEBUG="${HUB_WINEDEBUG:--all}" WINEMSYNC=1 MTL_HUD_ENABLED=0 WINE_TF_EMULATION=1 WINE_TF_MAX_STEPS=0 WINE_TF_MAX_NS=0 WINEDLLOVERRIDES="IGOProxy32.exe=d;winemenubuilder.exe=d" ROSETTA_X87_PATH=... WINE_COMPATDB="$COMPAT" "$RT/bin/wine" 'C:\Program Files\Electronic Arts\EA Desktop\13.805.99.0\EA Desktop\EADesktop.exe' --in-process-gpu > "$log" 2>&1 &`, then prints `started pid <pid> log <log>`. So: runtime `Runtimes/hub-0-winemacfs-dxmtrtv` (Wine + winemac + DXMT), clean environment (`env -i`), Wine prefix `P` (the BF3Mac `Data/Prefix` symlink also points to `P`), EA Desktop 13.805.99.0 launched with `--in-process-gpu`, all Wine/EA output (stderr and stdout, `WINEDEBUG=-all` unless `HUB_WINEDEBUG` set) in `Hub/Logs/ea-*.log`; EA's own logs in `P/drive_c/ProgramData/EA Desktop/Logs`.
- Wine starts the prefix's wineserver on demand; it stays alive afterwards (observed for the other prefix as `wineserver -p`, with services.exe, PnkBstrA.exe and a `C:\standin\EABackgroundService.exe`), which is why a plain process check for `wine` is not enough and `wineserver -w`/`-k` are used.

Clean stop (from `nfs-ea-import-plan-20261011.md` S1 and `cleanup-bf1-f1-20261011.log`, both used successfully today): (1) in the EA app pause downloads and use menu **Quit** (flushes the install store); quit any game; (2) block with `wineserver -w` using the same env as start-ea.sh (`env -i ... WINEPREFIX=P "$RT/bin/wineserver" -w`); fallback `wine taskkill /f /im EADesktop.exe|EACefSubProcess.exe|EABackgroundService.exe|EAGEP.exe`, then `wineserver -k` followed by `wineserver -w` (cleanup log: `wineserver -k exit=0`, `-w exit=0` 46 s later). Registry edits through Wine used a bare `wineserver -p` + `wine reg delete ... /reg:64`, then `wineserver -k` + `-w`. **Because the Wine hives are rewritten when wineserver exits, text edits of `system.reg`/`user.reg` must happen only after `wineserver -k` + `-w` have returned for `P` and no process has `WINEPREFIX=.../Prefix`.** Never use `sleep`; wait with `wineserver -w`.

## Appendix B: precedent (NFS import, `docs/history/nfs-ea-import-plan-20261011.md`, executed; STATUS 17:50 "NFS 2015 runs from the shared EA app (user-confirmed)")

- Game folder moved by same-volume `rename` to `E:\EA Games\Need for Speed` (outside the old library root `E:\EA Games\BF4\`).
- Registry: **only** `HKLM\SOFTWARE\Wow6432Node\EA Games\Need for Speed` with `"Install Dir"="E:\\EA Games\\Need for Speed\\"`, `Locale`, `Product GUID` was imported (`wine reg import nfs-import.reg`, EA stopped). No `Uninstall`, GDF/GameUX, `Origin Games` or `InstallData` records were fabricated, and none are needed: EA's `installCheck` (`watchPath` on `[HKLM\...\Install Dir]NFS16.exe`) found the game and logged `Located files ... Setting state to Installed` / `installedStatus=[Installed]`.
- `user.downloadinplacedir` was left at the BF4 library root; licence for NFS was not copied (machine-binding mismatch seen for BF3 `70619.dlf` after `e:` was added: `Mismatched machine hash in license` / `License Failure 3`; fixed by moving the dlf aside) and EA issued a fresh `1024486.dlf` on first Play.
- Success criteria used there (reusable): the four log lines (`watchPath path [E:\...]`, `Located files ...`, `launcher.exePath=[[HKEY_LOCAL_MACHINE\...\Install Dir]...]`, `IS update: ... installedStatus=[Installed]`) read from byte offsets recorded before EA start, plus the UI showing Play. Backups: cloned copies (`cp -c -p`) of the three hives and `ProgramData/EA Desktop` with SHA256SUMS, journal file; `mv -n` always followed by an existence check; a `stopped` gate (no wine/EA/game process, `prefixNotInUse`).
- Registry edits for the BF1 removal today used `wine reg delete` (5 deletes) rather than text edits; there is no precedent for text-editing a Wine hive in this project, but the format is plain and the plan's fallback section documents appending to a hive while the prefix is stopped.

## Appendix C: symlinks and cross-references

- `find G -maxdepth 4 -type l` (excluding `Backups/git` and `/Volumes/ExT2/Bundles`): 287 symlinks; only two relate to this work: `G/Library/EA -> ../EA Games` (stays valid) and `G/Relocated/BF3Mac/Data/Prefix -> ../../../Prefix`. **No symlink anywhere points into `EA Games/BF4` or the BF3 folder.** `P/dosdevices`: `c: -> ../drive_c`, `e: -> /Volumes/ExT2/GameHub`, `z: -> /`; no symlinks in the top two levels of `P/drive_c`. `~/Library/Application Support/BF3Mac/Data/Prefix -> /Volumes/ExT2/GameHub/Prefix`.
- Hub config (`G/Hub/hub.json`, `Hub/State`, `Apps`, `bin`, `Library/EA`) has no reference to `EA Games/BF4` or the BF3 path. **But the source recipe `work/wt-hub-a/Packaging/Recipes/bf3.json` sets `"gameRoot": "Program Files/EA Games/Battlefield 3"` (launch chain `BF3WebHelper.exe` -> `bf3.exe`)**, so the BF3 wrapper/Hub recipe expects BF3 inside `drive_c`.

## (e) Open risks

1. **BF3 wrapper app / Hub recipe**: the `Battlefield 3 Bundled ... .app` wrapper (BF3Mac) and `Packaging/Recipes/bf3.json` assume `drive_c\Program Files\EA Games\Battlefield 3`. NFS taught us the wrappers walk `drive_c` components without following links and throw on symlinks, so a compatibility symlink at the old BF3 path is not a safe fallback. After M5 the BF3 wrapper may fail its game-root check. Needs a decision (keep wrapper working with a hard-link mirror like NFS, update the recipe, or accept).
2. **Old NFS wrapper** (`Bundles/Need for Speed Bundled ...`) will stop working once the mirror is removed (user-approved); its own prefix registry keeps the dangling `C:\\Program Files\\EA Games\\Need for Speed\\`.
3. **Licences**: `.dlf` files are machine-bound; BF3's was already invalidated once by a drive-count change. Do not add/remove drive letters in `P/dosdevices`. Moving a game may require EA to re-validate; each Play can consume an EA activation (EA's limit; not verified) and Denuvo activations for some titles.
4. **EA install store (IS) is encrypted**: it may still hold the old locations. Expectation (from the NFS precedent and `launcher.exePath` templates) is that EA re-reconciles from the registry `Install Dir` and `watchPath` and rewrites IS. If EA instead shows Download/Install, the fallback is to point EA at the folder by re-running its "locate game" flow or restoring the backup. First start after the edit should be watched through the four log lines above. `downloadinplacedir` must be changed to `E:\EA Games\` or EA will keep downloading/repairing into `E:\EA Games\BF4\`.
5. **Auto-update/repair**: EA's `forceTouchupInstallerAfterUpdate`/repair may write into the old library root; a repair of F1 24 was run today (`touchup.exe install -repair`). Disable updates/repairs while moving.
6. **The 18 MSI products installed from F1 24's `__Installer\customcomponent\CustomPrereq*_speech*` folders** point their `SourceList` to `E:\EA Games\BF4\F1 24\__Installer\customcomponent\...`; after the rewrite they will point to the new folder, which is correct; if the registry rewrite is skipped Windows Installer will only complain on repair.
7. **Shortcuts and Burn state files** (3 `Public\Desktop` .lnk, 2 live `state.rsm`) cannot be text-edited; they will dangle until recreated.
8. **Hive edit while Wine runs would be lost**: Wine rewrites the hives at wineserver exit. The persistent wineserver of the other job (`gepperf-tools` prefix) is unrelated, but do not run `wineserver -k` without `WINEPREFIX=P` set explicitly (a bare `wineserver -k` may target the wrong server).
9. **Changing key names**: the 6 Qt cache key headers in user.reg are optional; if rewritten by text edit nothing else depends on them.
10. **Disk**: 199.7 GB free and changing (other jobs write); renames need none. Finder `.DS_Store` files recreate themselves in folders Finder has opened: delete `G/EA Games/BF4/.DS_Store` last (Finder may recreate it after `rmdir` fails).
11. **F1 24 EA AntiCheat**: `Software\EA\AC\Installs` `"f12024"=dword:00000001` and the service `EAAntiCheatService` (`C:\Program Files\EA\AC\eaanticheat.gameservice.exe`) hold no game path; F1 24 anti-cheat crashes in Wine anyway (known, not part of this work).
12. Logs and `.dmp` files will keep mentioning old paths; that is expected and harmless.

---

## Result (applied 2026-10-11)

**All stages PASS.** The consolidation was applied 2026-10-11 18:00–18:30 UTC.

### Applied mapping

| # | Game | Source | Target | Status |
|---|---|---|---|---|
| M1 | Battlefield 4 | `G/EA Games/BF4/Battlefield 4` | `G/EA Games/Battlefield 4` | moved (same-volume rename) |
| M2 | Crysis 3 | `G/EA Games/BF4/Crysis 3` | `G/EA Games/Crysis 3` | moved |
| M3 | F1 24 | `G/EA Games/BF4/F1 24` | `G/EA Games/F1 24` | moved |
| M4 | (cleanup) | `G/EA Games/BF4` (empty except `.DS_Store`) | removed | deleted |
| M5 | Battlefield 3 | `P/drive_c/Program Files/EA Games/Battlefield 3` | `G/EA Games/Battlefield 3` | moved |
| M6 | Need for Speed | `G/EA Games/Need for Speed` | (no move) | already in place |
| M7 | NFS hard-link mirror | `G/Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed` | removed | deleted (144 links, 25 dirs, ~14.6 GB data inode references freed) |
| M8 | EA Desktop ini | `user.downloadinplacedir=E:\EA Games\BF4\` | `user.downloadinplacedir=E:\EA Games\` | rewritten |

### Registry and records rewritten

- **system.reg**: 113 values rewritten (R-BF4 rule: `E:\\EA Games\\BF4\\` → `E:\\EA Games\\`; F1 24 18 MSI speech products + BF4 + Crysis 3 + PunkBuster) + 8 values (R-BF3 rule: `C:\\Program Files\\EA Games\\Battlefield 3\\` → `E:\\EA Games\\Battlefield 3\\`).
- **user.reg**: 2 key-name headers (Qt 4.x plugin cache) rewritten for BF4-form paths, 4 for BF3-form paths.
- **EA Desktop user_5453960179173819204.ini**: `user.downloadinplacedir` rewritten (line 1 of 561 B file).
- **map.eacrc / installerdata.xml**: no absolute paths; untouched.
- **Encrypted IS/IQ/CATS2/CONF, .dlf licences**: untouched.

### Backups

`/Volumes/ExT2/GameHub/Backups/ea-consolidate-20261011T173024Z/`:
- `files/` – copies of hives, ProgramData/EA Desktop tree, and EA ini backup.
- `SHA256SUMS` – digest of all backed-up files.
- Pre-S4 subfolder (earlier backup from testing; valid but unused).

Also: `/Volumes/ExT2/GameHub/Backups/licenses-20261011` (BF3, F1 24, Crysis 3 licence files), `Crysis3-installerdata.xml.orig-20261011` (executeElevated edit predecessor, reverted).

### Rollback

Stop EA first (`/Volumes/ExT2/GameHub/bin/ea-stop.sh --apply`). Then:
```
/Volumes/ExT2/GameHub/docs/ea-consolidate-scripts/s4-rollback.sh --apply
/Volumes/ExT2/GameHub/docs/ea-consolidate-scripts/s2-rollback.sh --apply
```
Renames BF3 back to `drive_c/Program Files/EA Games/Battlefield 3`, restores BF4/Crysis 3/F1 24 to `EA Games/BF4/<game>`, renames NFS mirror back to `Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed`, and restores all registry and ini edits from backups.

### Stale items (no longer functional; benign)

- **3 `.lnk` shortcuts** in `P/drive_c/users/Public/Desktop/`: Battlefield 4, Crysis 3, F1 24 (binary shell links with old paths; cannot be safely text-edited; dangling but harmless).
- **2 Package Cache `state.rsm` files** (WiX Burn state for VC++ 2012 redist) with `WixBundleOriginalSource` still naming `E:\EA Games\BF4\Battlefield 4\...` (not editable, affects repair only; benign).
- **`work/wt-hub-a/Packaging/Recipes/bf3.json`** hard-codes `drive_c/Program Files/EA Games/Battlefield 3` (BF3 wrapper recipe; wrapper no longer launches; recipe must be updated for BF3 to run from the Hub instead of the old wrapper).

### EA reconciliation

EA Desktop detected the moved games on first launch after registry edits, logged "Detected software [...] moved from [old] to [new]", and confirmed `installedStatus=[Installed]` for all five games (Battlefield 4, Crysis 3, F1 24, Battlefield 3, Need for Speed). No download, repair, or verify operations were triggered. `watchPath` confirms scan of flat `E:\EA Games\<game>\` paths.

### Consequence: game launching

Old BF3 and NFS wrapper apps (`Bundles/Battlefield 3 Bundled ...` and `Bundles/Need for Speed Bundled ...`) no longer function because their game folders have been moved or removed. Both wrapper prefixes (`Relocated/BF3Mac/Data/Prefix` and `Relocated/NFS2015Mac/Data/Prefix`) retain stale registry entries but are not used. Games are now launched via the shared EA Desktop app: `/Volumes/ExT2/GameHub/bin/start-ea.sh`.

### Hub code update

Commit 57b3848 on `nfs-macos` main: EA scanner now supports the flat `EA Games/<Game>` layout (previously reported `__Installer` folder as a bogus game), returns every game in a container, prefers installer marker over stray exe, skips hidden folders. 1447 tests passing.
