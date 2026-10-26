#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

static FILE *out;
static DWORD t0;
static void L(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    fprintf(out, "%6lu ms  ", (unsigned long)(GetTickCount() - t0));
    vfprintf(out, fmt, ap); fputc('\n', out); fflush(out); va_end(ap);
}
static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
    case WM_LBUTTONDOWN: L("WM_LBUTTONDOWN"); break;   case WM_LBUTTONUP: L("WM_LBUTTONUP"); break;
    case WM_RBUTTONDOWN: L("WM_RBUTTONDOWN"); break;   case WM_RBUTTONUP: L("WM_RBUTTONUP"); break;
    case WM_MBUTTONDOWN: L("WM_MBUTTONDOWN"); break;   case WM_MBUTTONUP: L("WM_MBUTTONUP"); break;
    case WM_XBUTTONDOWN: L("WM_XBUTTONDOWN XBUTTON%d", HIWORD(w)); break;
    case WM_XBUTTONUP:   L("WM_XBUTTONUP   XBUTTON%d", HIWORD(w)); break;
    case WM_MOUSEWHEEL:  L("WM_MOUSEWHEEL  delta %d", (short)HIWORD(w)); break;
    case WM_MOUSEHWHEEL: L("WM_MOUSEHWHEEL delta %d", (short)HIWORD(w)); break;
    case WM_KEYDOWN: case WM_SYSKEYDOWN:
        if (!(l & (1 << 30)) && ((w >= 0x70 && w <= 0x87) || w == 0xDB || w == 0xDD || (w >= 0xA6 && w <= 0xB3)))
            L("WM_KEYDOWN vk 0x%02lx scan 0x%02lx%s", (unsigned long)w, (unsigned long)((l >> 16) & 0xff), (l & (1<<24)) ? " ext" : "");
        break;
    case WM_INPUT: {
        UINT sz = 0; GetRawInputData((HRAWINPUT)l, RID_INPUT, NULL, &sz, sizeof(RAWINPUTHEADER));
        RAWINPUT *ri = malloc(sz);
        if (ri && GetRawInputData((HRAWINPUT)l, RID_INPUT, ri, &sz, sizeof(RAWINPUTHEADER)) == sz) {
            if (ri->header.dwType == RIM_TYPEMOUSE) {
                RAWMOUSE *r = &ri->data.mouse;
                if (r->usButtonFlags) L("RAW mouse buttonFlags 0x%04x data %d", r->usButtonFlags, (short)r->usButtonData);
            }
        }
        free(ri);
        break; }
    case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProcA(h, m, w, l);
}
int main(int argc, char **argv) {
    out = fopen(argc > 1 ? argv[1] : "mxprobe.log", "w");
    t0 = GetTickCount();
    WNDCLASSA wc = {0}; wc.lpfnWndProc = proc; wc.hInstance = GetModuleHandleA(NULL);
    wc.lpszClassName = "mxprobe"; wc.hCursor = LoadCursorA(NULL, IDC_ARROW); wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassA(&wc);
    HWND h = CreateWindowA("mxprobe", "mxprobe - press buttons here", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 200, 200, 900, 500, NULL, NULL, wc.hInstance, NULL);
    RAWINPUTDEVICE rid[1] = {{0x01, 0x02, RIDEV_INPUTSINK, h}};
    L("RegisterRawInputDevices: %s", RegisterRawInputDevices(rid, 1, sizeof(rid[0])) ? "ok" : "FAILED");
    UINT n = 0; GetRawInputDeviceList(NULL, &n, sizeof(RAWINPUTDEVICELIST));
    L("raw input devices listed by Wine: %u", n);
    L("GetSystemMetrics(SM_CMOUSEBUTTONS) = %d, SM_MOUSEWHEELPRESENT = %d, SM_MOUSEHORIZONTALWHEELPRESENT = %d", GetSystemMetrics(SM_CMOUSEBUTTONS), GetSystemMetrics(SM_MOUSEWHEELPRESENT), GetSystemMetrics(SM_MOUSEHORIZONTALWHEELPRESENT));
    L("ready");
    MSG msg; while (GetMessageA(&msg, NULL, 0, 0) > 0) { TranslateMessage(&msg); DispatchMessageA(&msg); }
    return 0;
}
