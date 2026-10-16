/* Throwaway harness: a 32-bit parent that starts EAGEP with CreateProcess, like EA's (32-bit)
 * BackgroundService does, and prints the unix wall-clock time of the call, so the harness can
 * measure createProcess -> connect the way BGS's 3.5 s timer does. */
#include <windows.h>
#include <stdio.h>
int main(int argc, char **argv)
{
    WCHAR cmd[] = L"\"C:\\Program Files\\Electronic Arts\\EA Desktop\\13.805.11.6320-1791598480\\EA Desktop\\EAGEP.exe\"";
    WCHAR dir[] = L"C:\\Program Files\\Electronic Arts\\EA Desktop\\13.805.11.6320-1791598480\\EA Desktop\\";
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    FILETIME ft;
    ULONGLONG t;

    GetSystemTimePreciseAsFileTime(&ft);
    t = ((ULONGLONG)ft.dwHighDateTime << 32 | ft.dwLowDateTime) - 116444736000000000ULL;
    printf("createprocess_epoch=%llu.%07llu\n", t / 10000000, t % 10000000);
    fflush(stdout);
    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, CREATE_BREAKAWAY_FROM_JOB, NULL, dir, &si, &pi))
    {
        printf("CreateProcess failed %lu\n", GetLastError());
        return 1;
    }
    WaitForSingleObject(pi.hProcess, 20000);
    return 0;
}
