#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char**argv){ /* dump.exe exe module offset len out */
    DWORD pid=0; HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0); PROCESSENTRY32 pe={.dwSize=sizeof(pe)};
    for(BOOL ok=Process32First(s,&pe);ok;ok=Process32Next(s,&pe)) if(!_stricmp(pe.szExeFile,argv[1])) pid=pe.th32ProcessID;
    HANDLE p=OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,FALSE,pid); HMODULE m[512]; DWORD need; char n[64];
    EnumProcessModules(p,m,sizeof(m),&need); BYTE *base=0;
    for(unsigned i=0;i<need/sizeof(HMODULE);i++){ GetModuleBaseNameA(p,m[i],n,64); if(!_stricmp(n,argv[2])) base=(BYTE*)m[i]; }
    SIZE_T off=_strtoui64(argv[3],0,16), len=_strtoui64(argv[4],0,16), rd=0; BYTE *buf=malloc(len);
    ReadProcessMemory(p,base+off,buf,len,&rd); FILE*f=fopen(argv[5],"wb"); fwrite(buf,1,rd,f); fclose(f);
    printf("%s base %p read %zu bytes at +%zx\n",argv[2],base,rd,off); return 0; }
