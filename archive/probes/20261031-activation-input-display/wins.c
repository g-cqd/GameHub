#include <windows.h>
#include <stdio.h>
static BOOL CALLBACK cb(HWND h, LPARAM p){ DWORD pid; GetWindowThreadProcessId(h,&pid); char c[64],t[64]; GetClassNameA(h,c,64); GetWindowTextA(h,t,64);
 if(strstr(t,"Watch")||strstr(c,"Watch")||strstr(c,"Disrupt")){ RECT r; GetWindowRect(h,&r);
 printf("hwnd %p pid %04lx class '%s' title '%s' visible=%d iconic=%d rect %ld,%ld-%ld,%ld style %08lx ex %08lx\n",h,pid,c,t,IsWindowVisible(h),IsIconic(h),r.left,r.top,r.right,r.bottom,GetWindowLongA(h,GWL_STYLE),GetWindowLongA(h,GWL_EXSTYLE)); }
 return TRUE; }
int main(void){ EnumWindows(cb,0); HWND f=GetForegroundWindow(); char t[64]={0}; GetWindowTextA(f,t,64); printf("foreground %p '%s' desktop %p shell %p\n",f,t,GetDesktopWindow(),GetShellWindow()); return 0; }
