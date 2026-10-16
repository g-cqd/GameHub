/* 32-bit x87 throughput probe: with the x87sidecar hook installed this runs many times faster
 * than under stock Rosetta, so it shows whether the hook is in place in the started process. */
#include <windows.h>
#include <stdio.h>
int main(void)
{
    LARGE_INTEGER f, a, b;
    volatile double x = 1.0;
    double y = 0.0;
    int i;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&a);
    for (i = 0; i < 20000000; i++) { y = y / 1.0000001 + x; }
    QueryPerformanceCounter(&b);
    printf("x87 loop %.0f ms (result %.3f)\n", (double)(b.QuadPart - a.QuadPart) * 1000.0 / f.QuadPart, y);
    return 0;
}
