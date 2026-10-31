#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
static HMODULE mods[1024]; static MODULEINFO mi[1024]; static char mn[1024][64]; static int nm;
static const char *where(HANDLE p, DWORD64 a, DWORD64 *off){
    for(int i=0;i<nm;i++){ DWORD64 b=(DWORD64)mi[i].lpBaseOfDll; if(a>=b && a<b+mi[i].SizeOfImage){*off=a-b; return mn[i];} }
    *off=a; return "?";
}
int main(int argc,char**argv){
    DWORD pid=0; HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0); PROCESSENTRY32 pe={.dwSize=sizeof(pe)};
    for(BOOL ok=Process32First(s,&pe);ok;ok=Process32Next(s,&pe)) if(!_stricmp(pe.szExeFile,argv[1])) pid=pe.th32ProcessID;
    CloseHandle(s); if(!pid){printf("no process\n");return 1;}
    HANDLE p=OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,FALSE,pid); DWORD need;
    EnumProcessModules(p,mods,sizeof(mods),&need); nm=need/sizeof(HMODULE);
    for(int i=0;i<nm;i++){ GetModuleInformation(p,mods[i],&mi[i],sizeof(mi[i])); GetModuleBaseNameA(p,mods[i],mn[i],64); }
    DWORD tids[256]; int nt=0;
    s=CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD,0); THREADENTRY32 te={.dwSize=sizeof(te)};
    for(BOOL ok=Thread32First(s,&te);ok;ok=Thread32Next(s,&te)) if(te.th32OwnerProcessID==pid && nt<256) tids[nt++]=te.th32ThreadID;
    for(int r=0;r<atoi(argv[2]);r++){
      for(int k=0;k<nt;k++){
        HANDLE t=OpenThread(THREAD_SUSPEND_RESUME|THREAD_GET_CONTEXT,FALSE,tids[k]); if(!t) continue;
        CONTEXT c={.ContextFlags=CONTEXT_CONTROL|CONTEXT_INTEGER}; SuspendThread(t); BOOL ok=GetThreadContext(t,&c);
        DWORD64 stk[96]={0}; SIZE_T rd=0; if(ok) ReadProcessMemory(p,(void*)c.Rsp,stk,sizeof(stk),&rd);
        ResumeThread(t); CloseHandle(t); if(!ok) continue;
        DWORD64 off; const char *m=where(p,c.Rip,&off);
        if(!_stricmp(m,"ntdll.dll") || !_stricmp(m,"win32u.dll")) continue;   /* waiting in a syscall */
        printf("r%d %04lx rip %s+%llx rcx=%llx |", r, tids[k], m, off, c.Rcx);
        int shown=0; for(int j=0;j<96&&shown<7;j++){ DWORD64 o; const char*w=where(p,stk[j],&o); if(*w!='?'){printf(" %s+%llx",w,o);shown++;} }
        printf("\n");
      }
      Sleep(150);
    }
    return 0;
}
