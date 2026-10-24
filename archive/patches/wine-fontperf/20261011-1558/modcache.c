/* Without loading user32: "del" deletes the MacFontCache value; "stamp" bumps the mtime_nsec of
 * the first stored folder stamp (header 20 bytes, stamp {dev, ino, sec, nsec}), so the next
 * process must see a changed folder. Prints the stored folder list. */
#include <windows.h>
#include <stdio.h>
#include <string.h>
int wmain(int argc, wchar_t **argv)
{
    static const wchar_t key[] = L"Software\\Wine\\Fonts\\MacFontCache";
    static BYTE buf[4 << 20]; DWORD size = sizeof(buf), type; HKEY h;
    if (argc > 1 && !wcscmp(argv[1], L"del")) return RegDeleteKeyValueW(HKEY_CURRENT_USER, key, L"Files");
    if (RegOpenKeyExW(HKEY_CURRENT_USER, key, 0, KEY_ALL_ACCESS, &h)) return 1;
    if (RegQueryValueExW(h, L"Files", NULL, &type, buf, &size)) return 2;
    UINT *hdr = (UINT *)buf; char *s = (char *)(buf + 20 + hdr[2] * 32);
    printf("magic %08x version %u dirs %u files %u size %lu\n", hdr[0], hdr[1], hdr[2], hdr[3], size);
    for (UINT i = 0; i < hdr[2]; i++) { printf("dir %s\n", s); s += strlen(s) + 1; }
    if (argc > 1 && !wcscmp(argv[1], L"stamp"))
    {
        *(LONGLONG *)(buf + 20 + 24) += 1;
        if (RegSetValueExW(h, L"Files", 0, REG_BINARY, buf, size)) return 3;
        printf("bumped stamp 0\n");
    }
    RegCloseKey(h);
    return 0;
}
