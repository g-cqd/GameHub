/* Throwaway-prefix stand-in for the EABackgroundService service (measurement only).
 * Reports SERVICE_RUNNING and writes its PID and the harness port into backgroundservice.ini;
 * the harness listener on 127.0.0.1:50999 plays BGS's IPC endpoint. */
#include <windows.h>
#include <stdio.h>
static SERVICE_STATUS_HANDLE h;
static SERVICE_STATUS st = { SERVICE_WIN32_OWN_PROCESS, SERVICE_RUNNING, SERVICE_ACCEPT_STOP };
static HANDLE stop_event;
static DWORD WINAPI ctrl(DWORD c, DWORD t, void *d, void *x)
{
    if (c == SERVICE_CONTROL_STOP) { st.dwCurrentState = SERVICE_STOPPED; SetServiceStatus(h, &st); SetEvent(stop_event); }
    return NO_ERROR;
}
static void WINAPI svc_main(DWORD argc, WCHAR **argv)
{
    FILE *f;
    stop_event = CreateEventW(NULL, TRUE, FALSE, NULL);
    h = RegisterServiceCtrlHandlerExW(L"EABackgroundService", ctrl, NULL);
    if ((f = fopen("C:\\ProgramData\\EA Desktop\\backgroundservice.ini", "w")))
    {
        fprintf(f, "BackgroundServicePort=50999\nBackgroundServicePid=%lu\n", GetCurrentProcessId());
        fclose(f);
    }
    SetServiceStatus(h, &st);
    WaitForSingleObject(stop_event, INFINITE);
}
int main(void)
{
    SERVICE_TABLE_ENTRYW t[] = { { (WCHAR *)L"EABackgroundService", svc_main }, { NULL, NULL } };
    return !StartServiceCtrlDispatcherW(t);
}
