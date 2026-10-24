/* Throwaway harness helper: own a hidden window so the wineserver keeps its desktop process,
 * as EA's own windows do in the live prefix. */
#include <windows.h>
int main(void)
{
    MSG msg;
    CreateWindowExW(0, L"STATIC", L"keepdesk", 0, 0, 0, 1, 1, NULL, NULL, NULL, NULL);
    while (GetMessageW(&msg, NULL, 0, 0) > 0) DispatchMessageW(&msg);
    return 0;
}
