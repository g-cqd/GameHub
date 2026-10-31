#include <windows.h>
#include <stdio.h>
int main(void){ HWND h=FindWindowA("Watch_Dogs",NULL); if(!h){printf("no window\n");return 1;}
 BOOL a=SetForegroundWindow(h); SetActiveWindow(h); SetFocus(h); Sleep(500);
 printf("SetForegroundWindow=%d foreground now %p (game %p)\n",a,GetForegroundWindow(),h); return 0; }
