#define DIRECTINPUT_VERSION 0x0800
#define INITGUID
#include <windows.h>
#include <dinput.h>
#include <stdio.h>
static BOOL CALLBACK cb(LPCDIDEVICEINSTANCEA d, LPVOID p){ printf("type %08lx product '%s' instance '%s'\n", d->dwDevType, d->tszProductName, d->tszInstanceName); return DIENUM_CONTINUE; }
int main(void){ IDirectInput8A *di; HRESULT hr=DirectInput8Create(GetModuleHandleA(0),DIRECTINPUT_VERSION,&IID_IDirectInput8A,(void**)&di,0);
 if(FAILED(hr)){printf("create %08lx\n",hr);return 1;} printf("-- game controllers\n"); IDirectInput8_EnumDevices(di,DI8DEVCLASS_GAMECTRL,cb,0,DIEDFL_ATTACHEDONLY);
 printf("-- all\n"); IDirectInput8_EnumDevices(di,DI8DEVCLASS_ALL,cb,0,DIEDFL_ATTACHEDONLY); return 0; }
