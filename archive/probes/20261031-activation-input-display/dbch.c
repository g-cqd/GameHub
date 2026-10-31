#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char**argv){   /* dbch.exe exe addr value */
    DWORD pid=0; HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0); PROCESSENTRY32 pe={.dwSize=sizeof(pe)};
    for(BOOL ok=Process32First(s,&pe);ok;ok=Process32Next(s,&pe)) if(!_stricmp(pe.szExeFile,argv[1])) pid=pe.th32ProcessID;
    HANDLE p=OpenProcess(PROCESS_VM_READ|PROCESS_VM_WRITE|PROCESS_VM_OPERATION,FALSE,pid);
    void *a=(void*)_strtoui64(argv[2],NULL,16); unsigned char old=0,v=(unsigned char)strtoul(argv[3],NULL,16); SIZE_T n;
    ReadProcessMemory(p,a,&old,1,&n); char name[16]={0}; ReadProcessMemory(p,(char*)a+1,name,15,&n);
    BOOL ok=WriteProcessMemory(p,a,&v,1,&n); printf("channel '%s' flags %02x -> %02x (%s)\n",name,old,v,ok?"ok":"failed");
    return 0;
}
