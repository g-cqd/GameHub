#include <windows.h>
#include <stdio.h>
static HMONITOR first;
static BOOL CALLBACK cb(HMONITOR h, HDC d, LPRECT r, LPARAM p){ if(!first) first=h; (*(int*)p)++; return TRUE; }
static void check(const char *step){
    int n=0; HMONITOR old=first; first=NULL; EnumDisplayMonitors(NULL,NULL,cb,(LPARAM)&n); HMONITOR now=first; first=old;
    MONITORINFOEXW mi={.cbSize=sizeof(mi)}; BOOL ok=GetMonitorInfoW(old,(MONITORINFO*)&mi); DWORD e=GetLastError();
    DEVMODEW dm={.dmSize=sizeof(dm)}; EnumDisplaySettingsW(NULL,ENUM_CURRENT_SETTINGS,&dm);
    printf("%-22s monitors=%d first=%p cached=%p info=%s(err %lu) rc=%ldx%ld mode=%lux%lu\n",step,n,now,old,ok?"ok":"FAIL",ok?0:e,
        ok?mi.rcMonitor.right-mi.rcMonitor.left:0, ok?mi.rcMonitor.bottom-mi.rcMonitor.top:0, dm.dmPelsWidth, dm.dmPelsHeight);
}
int main(void){
    int n=0; EnumDisplayMonitors(NULL,NULL,cb,(LPARAM)&n); check("start");
    MONITORINFOEXW mi={.cbSize=sizeof(mi)}; GetMonitorInfoW(first,(MONITORINFO*)&mi);
    DEVMODEW m={.dmSize=sizeof(m)}; EnumDisplaySettingsW(mi.szDevice,ENUM_CURRENT_SETTINGS,&m);
    m.dmPelsWidth=1920; m.dmPelsHeight=1080; m.dmDisplayFrequency=60; m.dmFields=DM_PELSWIDTH|DM_PELSHEIGHT|DM_DISPLAYFREQUENCY|DM_BITSPERPEL;
    printf("set1 -> %ld\n", ChangeDisplaySettingsExW(mi.szDevice,&m,NULL,CDS_FULLSCREEN,NULL)); Sleep(500); check("after set 1920x1080");
    printf("restore -> %ld\n", ChangeDisplaySettingsExW(mi.szDevice,NULL,NULL,CDS_FULLSCREEN,NULL)); Sleep(500); check("after restore");
    printf("set2 -> %ld\n", ChangeDisplaySettingsExW(mi.szDevice,&m,NULL,CDS_FULLSCREEN,NULL)); Sleep(500); check("after set again");
    ChangeDisplaySettingsExW(mi.szDevice,NULL,NULL,0,NULL); Sleep(300); check("end");
    return 0;
}
