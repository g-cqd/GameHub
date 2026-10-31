#include <windows.h>
#include <stdio.h>
int main(void) {
    volatile ULONG *tick_low = (volatile ULONG *)(0x7ffe0000 + 0x320);    /* TickCount.LowPart */
    volatile ULONG *itime_low = (volatile ULONG *)(0x7ffe0000 + 0x8);     /* InterruptTime.LowPart */
    ULONG t0 = *tick_low, i0 = *itime_low; DWORD g0 = GetTickCount();
    for (int k = 0; k < 20; k++) {
        /* pure spin: no API call in between, like the game's loop */
        LARGE_INTEGER f, a, b; QueryPerformanceFrequency(&f); QueryPerformanceCounter(&a);
        do { QueryPerformanceCounter(&b); } while ((b.QuadPart - a.QuadPart) * 1000 / f.QuadPart < 100);
        printf("k=%2d kusd_tick=+%lu ms  kusd_itime=+%lu00ns  GetTickCount=+%lu ms\n", k,
               *tick_low - t0, (*itime_low - i0) / 100, GetTickCount() - g0);
    }
    return 0;
}
