/* fontenum: "min" = load user32/gdi32, touch a DC, exit (timing).
 *           "list" = dump every EnumFontFamiliesEx entry and some CreateFont matches, sorted. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static wchar_t **lines; static size_t nlines, cap;
static void add(const wchar_t *s){ if(nlines==cap){cap=cap?cap*2:4096;lines=realloc(lines,cap*sizeof(*lines));} lines[nlines++]=_wcsdup(s); }
static int cmp(const void *a,const void *b){ return wcscmp(*(wchar_t* const*)a,*(wchar_t* const*)b); }

static int CALLBACK cb(const LOGFONTW *lf, const TEXTMETRICW *tm, DWORD type, LPARAM lp)
{
    const ENUMLOGFONTEXW *e=(const void*)lf; const NEWTEXTMETRICEXW *n=(const void*)tm; wchar_t b[1024];
    swprintf(b,1024,L"E|%ls|%ls|%ls|%ls|cs=%d|t=%lu|h=%ld|w=%ld|wt=%ld|it=%d|pf=%d|ntm=%#lx|fs=%08lx %08lx %08lx %08lx %08lx %08lx",
        lf->lfFaceName,e->elfFullName,e->elfStyle,e->elfScript,lf->lfCharSet,type,tm->tmHeight,tm->tmAveCharWidth,tm->tmWeight,
        tm->tmItalic,tm->tmPitchAndFamily,n->ntmTm.ntmFlags,n->ntmFontSig.fsUsb[0],n->ntmFontSig.fsUsb[1],n->ntmFontSig.fsUsb[2],
        n->ntmFontSig.fsUsb[3],n->ntmFontSig.fsCsb[0],n->ntmFontSig.fsCsb[1]);
    add(b); return 1;
}

int wmain(int argc, wchar_t **argv)
{
    HDC dc = GetDC(0);
    if (argc < 2 || !wcscmp(argv[1], L"min")) { ReleaseDC(0, dc); return 0; }
    LOGFONTW lf = {0}; lf.lfCharSet = DEFAULT_CHARSET;
    EnumFontFamiliesExW(dc, &lf, cb, 0, 0);
    static const wchar_t *names[] = { L"Arial", L"Tahoma", L"MS Shell Dlg", L"MS Shell Dlg 2", L"Courier New",
        L"Times New Roman", L"Segoe UI", L"Verdana", L"SimSun", L"MS Gothic", L"Helvetica", L"Menlo", L"Futura",
        L"Geist", L"System", L"Fixedsys", L"Marlett", L"Symbol", L"Wingdings", L"NoSuchFont", L"" };
    for (unsigned i = 0; i < sizeof(names)/sizeof(*names); i++)
        for (int wt = 400; wt <= 700; wt += 300)
        {
            HFONT f = CreateFontW(-16,0,0,0,wt,0,0,0,DEFAULT_CHARSET,0,0,0,0,names[i]);
            HGDIOBJ o = SelectObject(dc, f); wchar_t face[64] = L"", b[512]; TEXTMETRICW tm; SIZE sz;
            GetTextFaceW(dc, 64, face); GetTextMetricsW(dc, &tm); GetTextExtentPoint32W(dc, L"The quick brown fox", 19, &sz);
            swprintf(b,512,L"C|%ls|%d|%ls|h=%ld|a=%ld|w=%ld|wt=%ld|cs=%d|pf=%d|ext=%ldx%ld",names[i],wt,face,tm.tmHeight,tm.tmAscent,
                tm.tmAveCharWidth,tm.tmWeight,tm.tmCharSet,tm.tmPitchAndFamily,sz.cx,sz.cy);
            add(b); SelectObject(dc, o); DeleteObject(f);
        }
    qsort(lines, nlines, sizeof(*lines), cmp);
    FILE *out = argc > 2 ? _wfopen(argv[2], L"w, ccs=UTF-8") : stdout;
    for (size_t i = 0; i < nlines; i++) fwprintf(out, L"%ls\n", lines[i]);
    if (out != stdout) fclose(out);
    ReleaseDC(0, dc);
    return 0;
}
